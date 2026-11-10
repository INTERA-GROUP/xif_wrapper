// Original author: Gonzalo Salinas Hernando <gonzalo.salinas@nvision.es>
// CV-X-IF v1.0 adaptation: Maryana Pyzh <maryana.pyzh@irvmic.com> INNOVA IRV Microelectronis, S.L
//
// Collect issue, register and commit data for each accepted instruction
// Register and commit may arrive in either order after issue starts
// Execution starts once all three are present and the instruction is not killed

`include "config_xif.svh"

module xif_wrapper
  import cvxif_instr_pkg::*;
#(
  parameter int unsigned        XIF_NUM_RS             = X_NUM_RS,
  parameter bit                 ISSUE_REGISTER_SPLIT   = 1'b0,
  parameter type                xif_hartid_t           = logic [31:0],
  parameter type                xif_issue_req_t        = cvxif_v1_pkg::x_issue_req_t,
  parameter type                xif_issue_resp_t       = cvxif_v1_pkg::x_issue_resp_t,
  parameter type                xif_register_t         = cvxif_v1_pkg::x_register_t,
  parameter type                xif_commit_t           = cvxif_v1_pkg::x_commit_t,
  parameter type                xif_result_t           = cvxif_v1_pkg::x_result_t,
  parameter int unsigned        NbInstr                = NbInstr_def,
  parameter copro_issue_resp_t  CoproInstr [NbInstr]   = CoproInstr_def,
  parameter int unsigned        INSTR_DEPTH            = 20,  // max in flight instructions at any time
  parameter int unsigned        XIF_NUM_HARTS          = cvxif_v1_pkg::X_NUM_HARTS
) (
  input  logic            clk_i,
  input  logic            rst_ni,

  // Issue channel: opcode + ID arrives here. We decode and reply in the same cycle
  // Register values are NOT here, they come through the register channel below
  input  xif_issue_req_t  x_issue_req_i,
  output xif_issue_resp_t x_issue_resp_o,
  input  logic            x_issue_valid_i,
  output logic            x_issue_ready_o,

  // Register channel: actual rs1/rs2/rs3 values from the CPU register file
  // May arrive the same cycle as issue or later, we handle both cases
  input  xif_register_t   x_register_i,
  input  logic            x_register_valid_i,
  output logic            x_register_ready_o,

  // Commit channel: "execute it" or "kill it"
  input  xif_commit_t     x_commit_i,
  input  logic            x_commit_valid_i,

  // Result channel: we drive this when a result is ready for the CPU
  output xif_result_t     x_result_o,
  output logic            x_result_valid_o,
  input  logic            x_result_ready_i,

  // Interface to the execution unit (any accelerator that might be used)
  if_xif_exe.xif_wrapper if_wrapper_exe
);

  // --------------------------------------------------------------------------
  // Configuration checks and data types
  // --------------------------------------------------------------------------

  // Width alignment check: rs_valid_mask vs register_read
  // Two packages define the width of the per-register-source valid mask differently
  // cvxif_instr_pkg uses (X_NUM_RS << XIF_DUAL_REG_READ), which doubles the count when dual-read is
  // enabled
  // cvxif_v1_pkg uses the additive form (X_NUM_RS + X_DUALREAD)
  // With dual-read off both give X_NUM_RS = 3, so there's no problem in the default config
  // But if someone enables dual-read in one package without touching the other, the widths diverge
  // silently
  // This check turns that into a hard elaboration error so you catch it before
  // spending time debugging mismatched bit fields
  localparam int unsigned RSVMASK_W  = X_NUM_RS << XIF_DUAL_REG_READ;
  localparam int unsigned REGRREAD_W = cvxif_v1_pkg::X_NUM_RS + cvxif_v1_pkg::X_DUALREAD;

  if (RSVMASK_W != REGRREAD_W) begin : gen_width_check
    $error(
      "xif_wrapper: rs_valid_mask width (%0d) != register_read width (%0d). Check XIF_DUAL_REG_READ vs X_DUALREAD across packages.",
      RSVMASK_W,
      REGRREAD_W
    );
  end

  // Collection buffer entry type
  // It has three compartments, one per channel, and a flag on each saying "this one arrived"
  // We also cache the predecoder response (xresp) at issue time so we never need to decode the same
  // instruction twice
  typedef struct packed {
    xif_issue_req_t xreq;
    xif_register_t  xreg;
    xif_commit_t    xcommit;
    logic           xreq_ready;     // issue channel received
    logic           xreg_ready;     // register values received
    logic           xcommit_ready;  // commit received
    x_issue_resp_t  xresp;          // predecoder answer, latched at issue time
  } collected_values_t;

  localparam int unsigned ENTRY_IDX_WIDTH = (INSTR_DEPTH > 1) ? $clog2(INSTR_DEPTH) : 1;
  localparam int unsigned ENTRY_CNT_WIDTH = $clog2(INSTR_DEPTH + 1);
  localparam int unsigned ID_COUNT        = 2 ** X_ID_WIDTH;
  localparam int unsigned HART_IDX_WIDTH  = (XIF_NUM_HARTS > 1) ? $clog2(XIF_NUM_HARTS) : 1;

  // --------------------------------------------------------------------------
  // Issue history and commit decisions
  // --------------------------------------------------------------------------

  // Remember decisions after buffer slots are released, until the ID is used again
  typedef struct packed {
    logic                  valid;
    xif_hartid_t           hartid;
    logic [X_ID_WIDTH-1:0] newest_id;
    logic [ID_COUNT-1:0]   known;
    logic [ID_COUNT-1:0]   decided;
    logic [ID_COUNT-1:0]   killed;
  } hart_state_t;
  hart_state_t               hart_state_q [XIF_NUM_HARTS];
  hart_state_t               hart_state_d [XIF_NUM_HARTS];
  logic                      issue_hart_found;
  logic [HART_IDX_WIDTH-1:0] issue_hart_idx;
  logic                      pending_issue_q;
  logic [X_ID_WIDTH-1:0]     pending_issue_id_q;
  xif_hartid_t               pending_issue_hart_q;

  // Unsigned age keeps the issue order when IDs wrap, even across a large gap
  function automatic logic [X_ID_WIDTH-1:0] id_age (
    input logic [X_ID_WIDTH-1:0] newest,
    input logic [X_ID_WIDTH-1:0] id
  );
    return newest - id;
  endfunction

  // Observe the complete issue stream, including rejected and stalled requests
  always_comb begin : update_hart_state
    logic                      free_hart_found;
    logic [HART_IDX_WIDTH-1:0] free_hart_idx;

    hart_state_d = hart_state_q;

    issue_hart_found = 1'b0;
    issue_hart_idx   = '0;
    free_hart_found  = 1'b0;
    free_hart_idx    = '0;

    for (int h = 0; h < XIF_NUM_HARTS; h++) begin
      if (hart_state_q[h].valid && hart_state_q[h].hartid == x_issue_req_i.hartid) begin
        issue_hart_found = 1'b1;
        issue_hart_idx   = HART_IDX_WIDTH'(h);
      end

      if (!free_hart_found && !hart_state_q[h].valid) begin
        free_hart_found = 1'b1;
        free_hart_idx   = HART_IDX_WIDTH'(h);
      end
    end

    if (!issue_hart_found && free_hart_found) begin
      issue_hart_found = 1'b1;
      issue_hart_idx   = free_hart_idx;
    end

    if (
      rst_ni && x_issue_valid_i && issue_hart_found &&
      (!pending_issue_q || pending_issue_id_q != x_issue_req_i.id ||
       pending_issue_hart_q != x_issue_req_i.hartid)
    ) begin
      if (!hart_state_q[issue_hart_idx].valid) begin
        hart_state_d[issue_hart_idx]        = '0;
        hart_state_d[issue_hart_idx].valid  = 1'b1;
        hart_state_d[issue_hart_idx].hartid = x_issue_req_i.hartid;
      end else begin
        // Skipped IDs also belong to a new generation after passing them
        for (int id = 0; id < ID_COUNT; id++) begin
          if (
            id_age(x_issue_req_i.id, X_ID_WIDTH'(id)) <
            id_age(x_issue_req_i.id, hart_state_q[issue_hart_idx].newest_id)
          ) begin
            hart_state_d[issue_hart_idx].known[id]   = 1'b0;
            hart_state_d[issue_hart_idx].decided[id] = 1'b0;
            hart_state_d[issue_hart_idx].killed[id]  = 1'b0;
          end
        end
      end

      hart_state_d[issue_hart_idx].newest_id = x_issue_req_i.id;

      hart_state_d[issue_hart_idx].known[x_issue_req_i.id]   = 1'b1;
      hart_state_d[issue_hart_idx].decided[x_issue_req_i.id] = 1'b0;
      hart_state_d[issue_hart_idx].killed[x_issue_req_i.id]  = 1'b0;
    end

    if (rst_ni && x_commit_valid_i) begin
      for (int h = 0; h < XIF_NUM_HARTS; h++) begin
        if (
          hart_state_d[h].valid &&
          hart_state_d[h].hartid == x_commit_i.hartid &&
          !hart_state_d[h].decided[x_commit_i.id]
        ) begin
          for (int id = 0; id < ID_COUNT; id++) begin
            if (
              hart_state_d[h].known[id] && !hart_state_d[h].decided[id] &&
              (x_commit_i.commit_kill ?
                id_age(hart_state_d[h].newest_id, X_ID_WIDTH'(id)) <=
                  id_age(hart_state_d[h].newest_id, x_commit_i.id) :
                id_age(hart_state_d[h].newest_id, X_ID_WIDTH'(id)) >=
                  id_age(hart_state_d[h].newest_id, x_commit_i.id))
            ) begin
              hart_state_d[h].decided[id] = 1'b1;
              hart_state_d[h].killed[id]  = x_commit_i.commit_kill;
            end
          end

          // Remember the boundary too, even if this coprocessor rejected its issue
          hart_state_d[h].decided[x_commit_i.id] = 1'b1;
          hart_state_d[h].killed[x_commit_i.id]  = x_commit_i.commit_kill;
        end
      end
    end
  end

  // --------------------------------------------------------------------------
  // Collection buffer and decoder signals
  // --------------------------------------------------------------------------

  // collected_current_state holds the current (registered) state
  // collected_next_state is the next state, computed every cycle
  collected_values_t collected_current_state [INSTR_DEPTH];
  collected_values_t collected_next_state [INSTR_DEPTH];

  // Every cycle we sweep through all INSTR_DEPTH slots and compute three things
  //   free_idx    -> first empty slot we can assign to a new issue
  //   xreg_idx    -> slot whose ID matches the incoming register channel
  //   ready_idx   -> first slot with all three channels present, not killed
  // We use the lowest matching index to keep the control logic simple
  logic [ENTRY_IDX_WIDTH-1:0] free_idx;
  logic [ENTRY_IDX_WIDTH-1:0] xreg_idx;
  logic [ENTRY_IDX_WIDTH-1:0] ready_idx;
  logic                       free_found;
  logic                       xreg_found;
  logic                       ready_found;

  // Match register data that arrives in the same cycle as its issue
  logic new_xreg_match;

  // Only accepted issue handshakes allocate a buffer slot
  logic issue_fire;
  logic xreg_fire;

  // Number of occupied slots
  logic [ENTRY_CNT_WIDTH-1:0] buf_usage;

  // Decode-only issue request
  // The predecoder only needs the opcode, func3, and func7 fields to decide
  // whether an instruction is ours. It does NOT need rs values, those haven't
  // even arrived yet (they come through the register channel). Feeding it a
  // copy with rs 0ed out prevents using uninitialized data and also keeps
  // the decode independent of the register channel timing
  x_issue_req_t decode_x_issue_req_i;

  assign decode_x_issue_req_i.instr     = x_issue_req_i.instr;
  assign decode_x_issue_req_i.mode      = '0;
  assign decode_x_issue_req_i.hartid    = x_issue_req_i.hartid;
  assign decode_x_issue_req_i.id        = x_issue_req_i.id;
  assign decode_x_issue_req_i.rs        = '0;   // not available yet
  assign decode_x_issue_req_i.rs_valid  = '0;
  assign decode_x_issue_req_i.ecs       = '0;
  assign decode_x_issue_req_i.ecs_valid = 1'b0;

  x_issue_resp_t        resp_instr_predecoder;
  logic [RSVMASK_W-1:0] rs_valid_mask;

  // --------------------------------------------------------------------------
  // Instruction predecoder
  // --------------------------------------------------------------------------

  // Given the opcode it produces accept/writeback/register_read in the same cycle
  // The response goes back to the CPU immediately AND gets stored in the
  // collection buffer entry (xresp) for later use when we build
  // the execution request
  instr_predecoder #(
    .NbInstr    (NbInstr),
    .CoproInstr (CoproInstr),
    .X_NUM_RS   (X_NUM_RS)
  ) instr_decoder_i (
    .clk_i          (clk_i),
    .issue_valid_i  (x_issue_valid_i),
    .issue_ready_i  (x_issue_ready_o),
    .x_issue_req_i  (decode_x_issue_req_i),
    .x_issue_resp_o (resp_instr_predecoder),
    .rs_valid_mask  (rs_valid_mask)
  );
  assign x_issue_resp_o.accept        = resp_instr_predecoder.accept;
  assign x_issue_resp_o.writeback     = resp_instr_predecoder.writeback;
  assign x_issue_resp_o.register_read = REGRREAD_W'(rs_valid_mask);

  // --------------------------------------------------------------------------
  // Collection buffer scan
  // --------------------------------------------------------------------------

  // This block does ALL the searching in one pass. Every signal that needs to
  // know "where in the buffer does instruction X live" gets its answer here
  // Keeping it in one block avoids scanning the buffer multiple times per cycle
  always_comb begin
    free_found  = 1'b0;
    xreg_found  = 1'b0;
    ready_found = 1'b0;
    free_idx    = '0;
    xreg_idx    = '0;
    ready_idx   = '0;
    buf_usage   = '0;

    for (int unsigned i = 0; i < INSTR_DEPTH; i++) begin
      // Count occupied slots
      if (collected_current_state[i].xreq_ready) begin
        buf_usage = buf_usage + 1'b1;
      end

      // First free slot
      if (!free_found && !collected_current_state[i].xreq_ready) begin
        free_found = 1'b1;
        free_idx   = ENTRY_IDX_WIDTH'(i);
      end

      // Find the slot whose ID matches the incoming register data
      if (
        !xreg_found && collected_current_state[i].xreq_ready &&
        (collected_current_state[i].xreq.hartid == x_register_i.hartid) &&
        (collected_current_state[i].xreq.id == x_register_i.id)
      ) begin
        xreg_found = 1'b1;
        xreg_idx   = ENTRY_IDX_WIDTH'(i);
      end

      // Find the first instruction that has everything and is not being killed
      if (
        !ready_found &&
        collected_current_state[i].xreq_ready &&
        collected_current_state[i].xreg_ready &&
        collected_current_state[i].xcommit_ready &&
        !collected_current_state[i].xcommit.commit_kill
      ) begin
        ready_found = 1'b1;
        ready_idx   = ENTRY_IDX_WIDTH'(i);
      end
    end
  end

  // No free slot means the buffer is full
  wire buf_full  = ~free_found;
  wire buf_empty = (buf_usage == '0);

  // --------------------------------------------------------------------------
  // Issue and register handshakes
  // --------------------------------------------------------------------------

  // Rejected instructions complete the handshake without using a buffer slot
  assign x_issue_ready_o =
      rst_ni && issue_hart_found &&
      (
        !resp_instr_predecoder.accept ||
        (
          free_found &&
          (
            ISSUE_REGISTER_SPLIT ||
            (
              x_register_valid_i &&
              x_register_i.id == x_issue_req_i.id &&
              x_register_i.hartid == x_issue_req_i.hartid &&
              ((x_register_i.rs_valid & rs_valid_mask) == rs_valid_mask)
            )
          )
        )
      );

  // If the register channel arrives in the exact same cycle as its issue,
  // xreg_found will be 0 (the slot doesn't exist in the buffer yet)
  assign new_xreg_match =
      issue_fire &&
      (x_register_i.hartid == x_issue_req_i.hartid) &&
      (x_register_i.id == x_issue_req_i.id);

  // Split mode accepts every register packet and discards rejected or unmatched IDs
  assign x_register_ready_o =
      rst_ni &&
      (ISSUE_REGISTER_SPLIT ? 1'b1 : x_issue_ready_o);

  assign issue_fire = x_issue_valid_i && x_issue_ready_o && resp_instr_predecoder.accept;
  assign xreg_fire  = x_register_valid_i && x_register_ready_o;

  // When ready_idx is valid, we pull together: opcode/hartid/id from the issue
  // channel and rs values from the register channel, then pack them into the
  // x_issue_t struct that the execution block expects
  x_issue_req_t temp_x_issue_req_i;
  x_issue_t     issue_instr_i;       // goes into the instruction FIFO
  x_issue_t     issue_instr_o;       // comes out the other side to the execution block

  always_comb begin
    temp_x_issue_req_i.instr     = collected_current_state[ready_idx].xreq.instr;
    temp_x_issue_req_i.mode      = '0;
    temp_x_issue_req_i.hartid    = collected_current_state[ready_idx].xreq.hartid;
    temp_x_issue_req_i.id        = collected_current_state[ready_idx].xreq.id;
    temp_x_issue_req_i.rs        = collected_current_state[ready_idx].xreg.rs;
    temp_x_issue_req_i.rs_valid  = collected_current_state[ready_idx].xreg.rs_valid;
    temp_x_issue_req_i.ecs       = '0;
    temp_x_issue_req_i.ecs_valid = 1'b0;
  end

  assign issue_instr_i.req  = temp_x_issue_req_i;
  assign issue_instr_i.resp = collected_current_state[ready_idx].xresp;

  // --------------------------------------------------------------------------
  // FIFO control signals
  // --------------------------------------------------------------------------

  logic fifo_instr_full, fifo_instr_empty;
  logic fifo_res_full,   fifo_res_empty;
  logic fifo_instr_push, fifo_instr_pop;
  logic fifo_res_push,   fifo_res_pop;
  logic [$clog2(INSTR_DEPTH+1)-1:0] fifo_instr_usage;
  logic [$clog2(INSTR_DEPTH+1)-1:0] fifo_res_usage;

  // Push an instruction into the FIFO only when the slot is complete and the FIFO has room
  assign fifo_instr_push = ready_found && ~fifo_instr_full;

  x_issue_fifo_res_t x_fifo_res_i;  // execution block -> result FIFO
  x_issue_fifo_res_t x_fifo_res_o;  // result FIFO -> CPU result channel

  assign fifo_res_pop  = x_result_ready_i & ~fifo_res_empty;
  assign fifo_res_push = x_fifo_res_i.result_valid_exec_o & ~fifo_res_full;

  // --------------------------------------------------------------------------
  // Collection buffer update
  // --------------------------------------------------------------------------

  always_comb begin
    collected_next_state = collected_current_state;

    // Release the slot sent to the instruction FIFO
    if (fifo_instr_push) begin
      collected_next_state[ready_idx] = '0;
    end

    // Store an accepted issue in the first free slot
    if (issue_fire) begin
      collected_next_state[free_idx]            = '0;
      collected_next_state[free_idx].xreq       = x_issue_req_i;
      collected_next_state[free_idx].xreq_ready = 1'b1;
      collected_next_state[free_idx].xresp      = resp_instr_predecoder;
    end

    // Store registers in their existing slot or in the slot just allocated
    if (xreg_fire) begin
      if (xreg_found) begin
        collected_next_state[xreg_idx].xreg       = x_register_i;
        collected_next_state[xreg_idx].xreg_ready = 1'b1;
      end else if (new_xreg_match) begin
        collected_next_state[free_idx].xreg       = x_register_i;
        collected_next_state[free_idx].xreg_ready = 1'b1;
      end
    end

    // Apply the group decision to every affected ID, including a new issue
    for (int i = 0; i < INSTR_DEPTH; i++) begin
      for (int h = 0; h < XIF_NUM_HARTS; h++) begin
        if (
          collected_next_state[i].xreq_ready && hart_state_d[h].valid &&
          collected_next_state[i].xreq.hartid == hart_state_d[h].hartid &&
          hart_state_d[h].decided[collected_next_state[i].xreq.id]
        ) begin
          if (hart_state_d[h].killed[collected_next_state[i].xreq.id]) begin
            collected_next_state[i] = '0;
          end else begin
            collected_next_state[i].xcommit_ready       = 1'b1;
            collected_next_state[i].xcommit.hartid      = collected_next_state[i].xreq.hartid;
            collected_next_state[i].xcommit.id          = collected_next_state[i].xreq.id;
            collected_next_state[i].xcommit.commit_kill = 1'b0;
          end
        end
      end
    end
  end

  // --------------------------------------------------------------------------
  // Registered state
  // --------------------------------------------------------------------------

  // Register the next state on every rising edge
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      collected_current_state <= '{default: '0};
      hart_state_q            <= '{default: '0};
      pending_issue_q         <= 1'b0;
      pending_issue_id_q      <= '0;
      pending_issue_hart_q    <= '0;
    end else begin
      collected_current_state <= collected_next_state;
      hart_state_q            <= hart_state_d;
      pending_issue_q         <= x_issue_valid_i && !x_issue_ready_o;

      if (x_issue_valid_i) begin
        pending_issue_id_q   <= x_issue_req_i.id;
        pending_issue_hart_q <= x_issue_req_i.hartid;
      end
    end
  end

  // --------------------------------------------------------------------------
  // Instruction FIFO
  // --------------------------------------------------------------------------

  fifo_v3 #(
    .FALL_THROUGH (1),
    .DEPTH        (INSTR_DEPTH),
    .dtype        (x_issue_t)
  ) fifo_instruction_i (
    .clk_i      (clk_i),
    .rst_ni     (rst_ni),
    .flush_i    (1'b0),
    .testmode_i (1'b0),
    .full_o     (fifo_instr_full),
    .empty_o    (fifo_instr_empty),
    .usage_o    (fifo_instr_usage),
    .data_i     (issue_instr_i),
    .push_i     (fifo_instr_push),
    .data_o     (issue_instr_o),
    .pop_i      (fifo_instr_pop)
  );

  // --------------------------------------------------------------------------
  // Result FIFO
  // --------------------------------------------------------------------------

  fifo_v3 #(
    .FALL_THROUGH (1),
    .DEPTH        (INSTR_DEPTH),
    .dtype        (x_issue_fifo_res_t)
  ) fifo_result_i (
    .clk_i      (clk_i),
    .rst_ni     (rst_ni),
    .flush_i    (1'b0),
    .testmode_i (1'b0),
    .full_o     (fifo_res_full),
    .empty_o    (fifo_res_empty),
    .usage_o    (fifo_res_usage),
    .data_i     (x_fifo_res_i),
    .push_i     (fifo_res_push),
    .data_o     (x_fifo_res_o),
    .pop_i      (fifo_res_pop)
  );

  // --------------------------------------------------------------------------
  // Execution interface
  // --------------------------------------------------------------------------

  // We signal valid when the instruction FIFO has something ready
  // The execution block pops when it is ready to consume it
  assign if_wrapper_exe.wrapper_exe_instr_valid = ~fifo_instr_empty;
  assign if_wrapper_exe.wrapper_exe_instr_issue = issue_instr_o;
  assign fifo_instr_pop =
      if_wrapper_exe.exe_wrapper_recv_instr_ready && ~fifo_instr_empty;

  // Tell the execution block whether we can accept its result right now
  assign if_wrapper_exe.wrapper_exe_recv_result_ready = ~fifo_res_full;
  assign x_fifo_res_i                                 = if_wrapper_exe.exe_wrapper_result;

  // --------------------------------------------------------------------------
  // Processor result interface
  // --------------------------------------------------------------------------

  always_comb begin
    x_result_o.hartid = xif_hartid_t'(x_fifo_res_o.issue_exec_o.req.hartid);
    x_result_o.id     = x_fifo_res_o.issue_exec_o.req.id;
    x_result_o.data   = x_fifo_res_o.result_data_exec_o;
    x_result_o.rd     = x_fifo_res_o.issue_exec_o.req.instr[11:7];
    x_result_o.we     = x_fifo_res_o.issue_exec_o.resp.writeback;
  end

  // --------------------------------------------------------------------------
  // Simulation checks
  // --------------------------------------------------------------------------

`ifndef SYNTHESIS
  initial begin
    assert (
      $bits(x_issue_req_i.id) == X_ID_WIDTH &&
      $bits(x_register_i.id) == X_ID_WIDTH &&
      $bits(x_commit_i.id) == X_ID_WIDTH
    ) else $error("xif_wrapper: ID widths must match cvxif_instr_pkg::X_ID_WIDTH");

    assert ($bits(xif_hartid_t) == $bits(x_fifo_res_o.issue_exec_o.req.hartid))
      else $error(
        "xif_wrapper: hartid width mismatch — xif_hartid_t is %0d bits, req.hartid is %0d bits",
        $bits(xif_hartid_t),
        $bits(x_fifo_res_o.issue_exec_o.req.hartid)
      );
  end
`endif

  assign x_result_valid_o = ~fifo_res_empty;

endmodule
