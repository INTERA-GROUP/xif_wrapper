// Author: Gonzalo Salinas Hernando <gonzalo.salinas@nvision.es>
// Description: Wrapper for the x-if interface - check diagram for better understanding of FIFOs management and interface signals
// Addition of new instr must be done in intr_package and execution modules


module xif_wrapper
import cvxif_instr_pkg::*;
#(
  parameter int unsigned NbInstr = NbInstr_def,
  parameter copro_issue_resp_t CoproInstr[NbInstr] = CoproInstr_def,
  parameter INSTR_DEPTH = 4  
)
(
    // Clock and Reset
    input logic clk_i,
    input logic rst_ni,
  
    // eXtension interface from copro side
    if_xif.coproc_compressed xif_compressed_if,
    if_xif.coproc_issue      xif_issue_if,
    if_xif.coproc_commit     xif_commit_if,
    if_xif.coproc_mem        xif_mem_if,
    if_xif.coproc_mem_result xif_mem_result_if,
    if_xif.coproc_result     xif_result_if,
    // interface for the exe block
    if_xif_exe.xif_wrapper   if_wrapper_exe
);

// Intermediate signals
  x_issue_t issue_commit_i; //Input to FIFO_commit
  x_issue_t issue_result_i; //Input to FIFO_result
  x_issue_t issue_commit_o; //Output from FIFO_commit - Input to FIFO_instr if POP in FIFO_commit + ~kill + accept
  x_issue_t issue_instr_o;  //Output from FIFO_instr - Input to execution block
  x_issue_t issue_exec_o;   //Output from execution block
  logic [(X_NUM_RS << XIF_DUAL_REG_READ)  -1:0]    rs_valid_mask; //rs_valid_mask from pre-decoder 
  logic     rs_valid_flag;

// FIFOs signals
  logic fifo_commit_full, fifo_commit_empty;
  logic fifo_instr_full, fifo_instr_empty;
  logic fifo_res_full, fifo_res_empty;
  logic fifo_commit_push, fifo_commit_pop, fifo_instr_pop, fifo_res_push, fifo_res_pop;
  logic [1:0] fifo_commit_usage;
  logic [1:0] fifo_instr_usage;
  logic [1:0] fifo_res_usage;
  x_issue_req_t  temp_x_issue_req_i;
  logic [31:0] temp_instr ;
//FIFO_result packed signals
  x_issue_fifo_res_t x_fifo_res_i; // Output from the execution block - Input to the FIFO_result
  x_issue_fifo_res_t x_fifo_res_o; // Output from the FIFO_result - Input to Result interface
  
//Compressed interface, never used
  assign xif_compressed_if.compressed_ready            = 0;
  assign xif_compressed_if.compressed_resp.instr       = '0;
  assign xif_compressed_if.compressed_resp.accept      = 0;

//mem interface, never used
  assign  xif_mem_if.mem_valid                         = 0;
  assign  xif_mem_if.mem_req                           = '0;
 
 // the issue for in verilator assginment  
  assign temp_x_issue_req_i.instr     = xif_issue_if.issue_req.instr;
  assign temp_x_issue_req_i.mode      = xif_issue_if.issue_req.mode;
  assign temp_x_issue_req_i.id        = xif_issue_if.issue_req.id;
  assign temp_x_issue_req_i.rs        = xif_issue_if.issue_req.rs;
  assign temp_x_issue_req_i.rs_valid  = xif_issue_if.issue_req.rs_valid;
  assign temp_x_issue_req_i.ecs       = xif_issue_if.issue_req.ecs;
  assign temp_x_issue_req_i.ecs_valid = xif_issue_if.issue_req.ecs_valid;

// Decoder: gets the issue_req and based on data on cvxif_instr_pkg provides issue_resp - combinational block
  instr_predecoder #(
    .NbInstr(NbInstr),
    .CoproInstr(CoproInstr),
    .X_NUM_RS(X_NUM_RS)
  ) instr_decoder_i (
      .clk_i         (clk_i),
      .issue_valid_i (xif_issue_if.issue_valid),
      .issue_ready_i (xif_issue_if.issue_ready),
      .x_issue_req_i (temp_x_issue_req_i),
      .x_issue_resp_o (xif_issue_if.issue_resp),
      .rs_valid_mask (rs_valid_mask)
  );

  //rs_valid_flag goes high when the required source registers are available
  assign rs_valid_flag = &(temp_x_issue_req_i.rs_valid | ~rs_valid_mask); // Reduction over the 'or' of rs_valid + not(rs_valid_mask) // Obtained with a Truth table and corresponding Karnough map
  //Issue ready if rs_valid and maximum instructions offloaded < DEPTH
  assign xif_issue_if.issue_ready = ~fifo_commit_full && ~fifo_instr_full && ~fifo_res_full && (fifo_commit_usage + fifo_instr_usage + fifo_res_usage < INSTR_DEPTH) && rs_valid_flag && rst_ni; // REAL FUNCTIONALITY, UNCOMMENT WHEN PROBLEM IS SORTED OUT! (rs_valid left out to avoid comb loops on the CPU side)

  //FIFO_commit signals                                                              
  assign fifo_commit_push = xif_issue_if.issue_valid && xif_issue_if.issue_ready && xif_issue_if.issue_resp.accept; // If issue transaction then issue_req and issue_resp go to fifo, if not accepted or kill they will be discarded later on
  assign issue_commit_i.req = temp_x_issue_req_i; // Issue req. goes to the fifo
  assign issue_commit_i.resp = xif_issue_if.issue_resp; // Corresponding Issue resp goes to the fifo as well

  //POP when commit_valid + issue transaction in progress or already done, if issue transaction has not happened yet then wait - All the commit transactions are in order matching with issue transactions
  assign fifo_commit_pop = xif_commit_if.commit_valid & (xif_commit_if.commit.id == issue_commit_o.req.id) & ~(xif_commit_if.commit.id == temp_x_issue_req_i.id && xif_issue_if.issue_valid && ~xif_issue_if.issue_ready);

  //FIFO_result signals
  assign fifo_res_pop = xif_result_if.result_ready & ~fifo_res_empty;
  assign fifo_res_push = x_fifo_res_i.result_valid_exec_o & ~fifo_res_full;

  // First FIFO to go through the issue and commit stages
  // Inputs data when issue transaction, outputs data when commit_valid + issue transaction done or in progress
  fifo_v3 #(
      .FALL_THROUGH(1),               //Combinational path if FIFO is empty
  //    .DATA_WIDTH  (64),
      .DEPTH       (INSTR_DEPTH),     // Maximum 4 instr to accept
      .dtype       (x_issue_t)        // We will input req and resp per instr
 //     .FPGA_EN     (CVA6Cfg.FPGA_EN) -> in the CVA6 repo there is an optimization for FPGA fifos, could be interesting
  ) fifo_commit_i (
      .clk_i     (clk_i),
      .rst_ni    (rst_ni),
      .flush_i   (1'b0),  // TODO - if necessary to flush in new x-if standard when kill a batch of offloaded instructions
      .testmode_i(1'b0),
      .full_o    (fifo_commit_full),
      .empty_o   (fifo_commit_empty),
      .usage_o   (fifo_commit_usage),
      .data_i    (issue_commit_i),
      .push_i    (fifo_commit_push),
      .data_o    (issue_commit_o),
      .pop_i     (fifo_commit_pop)
  );

// Second FIFO to go through decode/execution and result stages when commit has been asserted
  fifo_v3 #(
//   .FALL_THROUGH(1),              // STANDARD FIFO, generates the required clock latency by the x-if
    .FALL_THROUGH(1),               //Combinational path if FIFO is empty
//   .DATA_WIDTH  (64),
    .DEPTH       (INSTR_DEPTH),     // Maximum 4 instr to execute
    .dtype       (x_issue_t)        // We will input req and resp per instr
//   .FPGA_EN     (CVA6Cfg.FPGA_EN) -> in the CVA6 repo there is an optimization for FPGA fifos, could be interesting
  ) fifo_instruction_i (
    .clk_i     (clk_i),
    .rst_ni    (rst_ni),
    .flush_i   (1'b0),
    .testmode_i(1'b0),
    .full_o    (fifo_instr_full),
    .empty_o   (fifo_instr_empty),
    .usage_o   (fifo_instr_usage),
    .data_i    (issue_commit_o),
    .push_i    (fifo_commit_pop && ~xif_commit_if.commit.commit_kill && issue_commit_o.resp.accept && ~fifo_commit_empty), // We input data from FIFO_commit when fifo_commit_pop + no kill (commit) + accept instr.
    .data_o    (issue_instr_o),
    .pop_i     (fifo_instr_pop)
);

// Third FIFO to store the data comming from the execution block in case the CPU is not ready to receive it yet
  fifo_v3 #(
    .FALL_THROUGH(1), //Combinational path if FIFO is empty
//   .DATA_WIDTH  (64),
    .DEPTH       (INSTR_DEPTH), // Maximum 4 instr to execute //
    .dtype       (x_issue_fifo_res_t) // We will input req and resp per instr
//   .FPGA_EN     (CVA6Cfg.FPGA_EN) -> in the CVA6 repo there is an optimization for FPGA fifos, could be interesting
  ) fifo_result_i (
    .clk_i     (clk_i),
    .rst_ni    (rst_ni),
    .flush_i   (1'b0),
    .testmode_i(1'b0),
    .full_o    (fifo_res_full),
    .empty_o   (fifo_res_empty),
    .usage_o   (fifo_res_usage),
    .data_i    (x_fifo_res_i),
    .push_i    (fifo_res_push), 
    .data_o    (x_fifo_res_o),
    .pop_i     (fifo_res_pop)
);


assign if_wrapper_exe.wrapper_exe_instr_valid = ~fifo_instr_empty;
assign if_wrapper_exe.wrapper_exe_instr_issue = issue_instr_o;
assign fifo_instr_pop = if_wrapper_exe.exe_wrapper_recv_instr_ready;
  //Interface: Execution block <-> FIFO_result
assign if_wrapper_exe.wrapper_exe_recv_result_ready = ~fifo_res_full;
assign x_fifo_res_i = if_wrapper_exe.exe_wrapper_result;




// Result interface
  always_comb begin
        
    xif_result_if.result.data    = x_fifo_res_o.result_data_exec_o;  // Data processed by the custom instr
    //xif_result_if.result_valid   = x_fifo_res_o.result_valid_exec_o; // Data has been processed and is valid to be returned to CPU 
    xif_result_if.result_valid   = ~fifo_res_empty;
    xif_result_if.result.id      = x_fifo_res_o.issue_exec_o.req.id; // Giving back the instr id
    xif_result_if.result.rd      = x_fifo_res_o.issue_exec_o.req.instr[11:7]; // Giving back the dest reg
    xif_result_if.result.we      = x_fifo_res_o.issue_exec_o.resp.writeback; // Writeback?

    // Never used signals
    xif_result_if.result.exc     = 0;  // Did the instruction cause a synchronous exception?
    xif_result_if.result.exccode = '0;  // Exception code

    xif_result_if.result.ecsdata = '0;  // Write data value for {mstatus.xs, mstatus.fs, mstatus.vs}
    xif_result_if.result.ecswe = '0;  // Write enables for {mstatus.xs, mstatus.fs, mstatus.vs}

    xif_result_if.result.err = 0;  // Did the instruction cause a bus error?
    xif_result_if.result.dbg = 0;  // Did the instruction cause a debug trigger match with ``mcontrol.timing`` = 0?
   
  end

endmodule
