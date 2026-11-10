// Author: Maryana Pyzh, INNOVA IRV Microelectronics SL
// Follow instructions from the CPU through the wrapper and back
module tb_xif_wrapper_v1 #(
  parameter int NUM_INSTRUCTIONS = 25,
  parameter int BUFFER_DEPTH     = 20
);
  typedef cvxif_v1_pkg::id_t id_t;
  localparam logic [31:0] HART = 32'h12;
  localparam int MAX_CYCLES = NUM_INSTRUCTIONS * 20;

  logic clk            = 0;
  logic rst_n          = 0;
  logic issue_valid    = 0;
  logic issue_ready;
  logic register_valid = 0;
  logic register_ready;
  logic commit_valid   = 0;
  logic result_valid;
  logic result_ready   = 0;

  logic [31:0] instructions [NUM_INSTRUCTIONS];
  logic [2:0][31:0] operands [NUM_INSTRUCTIONS];
  bit supported [NUM_INSTRUCTIONS];
  bit kill_instruction [NUM_INSTRUCTIONS];
  bit [NUM_INSTRUCTIONS-1:0] issued, register_seen, commit_seen, executed, returned;

  int accepted_count, rejected_count, register_count, commit_count, kill_count;
  int execution_count, result_count, stall_cycles;
  int expected_accepted = 0;
  int expected_results  = 0;
  bit issue_waiting, result_held;

  cvxif_v1_pkg::x_issue_req_t  issue_req;
  cvxif_v1_pkg::x_issue_resp_t issue_resp;
  cvxif_v1_pkg::x_register_t   register_data;
  cvxif_v1_pkg::x_commit_t     commit_data;
  cvxif_v1_pkg::x_result_t     result_data, held_result;
  if_xif_exe exe_if();

  always #5 clk = ~clk;

  xif_wrapper #(
    .ISSUE_REGISTER_SPLIT (1'b1),
    .INSTR_DEPTH          (BUFFER_DEPTH)
  ) dut (
    .clk_i              (clk),
    .rst_ni             (rst_n),
    .x_issue_req_i      (issue_req),
    .x_issue_resp_o     (issue_resp),
    .x_issue_valid_i    (issue_valid),
    .x_issue_ready_o    (issue_ready),
    .x_register_i       (register_data),
    .x_register_valid_i (register_valid),
    .x_register_ready_o (register_ready),
    .x_commit_i         (commit_data),
    .x_commit_valid_i   (commit_valid),
    .x_result_o         (result_data),
    .x_result_valid_o   (result_valid),
    .x_result_ready_i   (result_ready),
    .if_wrapper_exe     (exe_if.xif_wrapper)
  );

  task automatic check(input int id, input logic condition, input string reason);
    if (condition !== 1'b1) begin
      if (id >= 0 && id < NUM_INSTRUCTIONS)
        $fatal(1, "FAIL: ID=%0d instruction=0x%08h: %s", id, instructions[id], reason);
      else
        $fatal(1, "FAIL: ID=%0d: %s", id, reason);
    end
  endtask

  function automatic logic [31:0] expected_result(input int id);
    return operands[id][0] * operands[id][1] + operands[id][2];
  endfunction

  // A small MAC model accepts the packet that would go to the accelerator
  assign exe_if.exe_wrapper_recv_instr_ready =
      rst_n && exe_if.wrapper_exe_recv_result_ready;

  always_comb begin
    exe_if.exe_wrapper_result.issue_exec_o = exe_if.wrapper_exe_instr_issue;
    exe_if.exe_wrapper_result.result_data_exec_o =
        exe_if.wrapper_exe_instr_issue.req.rs[0] *
        exe_if.wrapper_exe_instr_issue.req.rs[1] +
        exe_if.wrapper_exe_instr_issue.req.rs[2];
    exe_if.exe_wrapper_result.result_valid_exec_o =
        rst_n && exe_if.wrapper_exe_instr_valid;
  end

  // Observe real channel transfers and check the data for each ID
  always @(posedge clk) begin
    int id;
    if (!rst_n) begin
      issued          = '0;
      register_seen   = '0;
      commit_seen     = '0;
      executed        = '0;
      returned        = '0;
      accepted_count  = 0;
      rejected_count  = 0;
      register_count  = 0;
      commit_count    = 0;
      kill_count      = 0;
      execution_count = 0;
      result_count    = 0;
      stall_cycles    = 0;
      issue_waiting   = 0;
      result_held     = 0;
      held_result     = '0;
    end else begin
      if (issue_valid && !issue_ready) begin
        if (!issue_waiting)
          $display("WRAPPER -> CPU WAIT: ID=%0d ready=0", issue_req.id);
        if (issue_req.id == id_t'(BUFFER_DEPTH)) stall_cycles++;
      end
      issue_waiting = issue_valid && !issue_ready;

      if (issue_valid && issue_ready) begin
        id = int'(issue_req.id);
        check(id, id < NUM_INSTRUCTIONS, "unknown issue ID");
        check(id, !issued[id] && issue_req.instr == instructions[id] &&
                  issue_req.hartid == HART, "wrong or duplicate issue");
        check(id, issue_resp.accept == supported[id], "wrong accept response");
        check(id, issue_resp.register_read == (supported[id] ? 3'b111 : 3'b000) &&
                  issue_resp.writeback == supported[id], "wrong decoder response");
        issued[id] = 1;
        if (issue_resp.accept) accepted_count++;
        else                   rejected_count++;
        $display("WRAPPER -> CPU ISSUE: ID=%0d accept=%b register_read=%b writeback=%b",
                 id, issue_resp.accept, issue_resp.register_read, issue_resp.writeback);
      end

      if (register_valid && register_ready) begin
        id = int'(register_data.id);
        check(id, id < NUM_INSTRUCTIONS, "unknown register ID");
        check(id, issued[id] && !register_seen[id] && register_data.hartid == HART &&
                  register_data.rs == operands[id] &&
                  register_data.rs_valid == (supported[id] ? 3'b111 : 3'b000),
              "wrong or duplicate register packet");
        register_seen[id] = 1;
        register_count++;
        $display("CPU -> WRAPPER REGISTER: ID=%0d rs1=%0d rs2=%0d rs3=%0d rs_valid=%b",
                 id, register_data.rs[0], register_data.rs[1], register_data.rs[2],
                 register_data.rs_valid);
        if (!supported[id])
          $display("WRAPPER: ignored registers for rejected ID=%0d", id);
      end

      if (commit_valid) begin
        id = int'(commit_data.id);
        check(id, id < NUM_INSTRUCTIONS, "unknown commit ID");
        check(id, issued[id] && !commit_seen[id] && commit_data.hartid == HART &&
                  commit_data.commit_kill == kill_instruction[id],
              "wrong or duplicate commit");
        commit_seen[id] = 1;
        if (commit_data.commit_kill) begin
          kill_count++;
          $display("CPU -> WRAPPER KILL: ID=%0d", id);
        end else begin
          commit_count++;
          $display("CPU -> WRAPPER COMMIT: ID=%0d", id);
        end
      end

      if (exe_if.wrapper_exe_instr_valid && exe_if.exe_wrapper_recv_instr_ready) begin
        id = int'(exe_if.wrapper_exe_instr_issue.req.id);
        check(id, id < NUM_INSTRUCTIONS, "unknown execution ID");
        check(id, issued[id] && register_seen[id] && commit_seen[id] &&
                  supported[id] && !kill_instruction[id] && !executed[id],
              "rejected, killed, incomplete or duplicate execution");
        check(id, exe_if.wrapper_exe_instr_issue.req.instr == instructions[id] &&
                  exe_if.wrapper_exe_instr_issue.req.hartid == HART &&
                  exe_if.wrapper_exe_instr_issue.req.rs == operands[id] &&
                  exe_if.wrapper_exe_instr_issue.req.rs_valid == 3'b111 &&
                  exe_if.wrapper_exe_instr_issue.resp.writeback,
              "execution packet does not match the CPU inputs");
        executed[id] = 1;
        execution_count++;
        $display("WRAPPER -> ACCELERATOR: ID=%0d instruction=0x%08h rs1=%0d rs2=%0d rs3=%0d",
                 id, exe_if.wrapper_exe_instr_issue.req.instr,
                 exe_if.wrapper_exe_instr_issue.req.rs[0],
                 exe_if.wrapper_exe_instr_issue.req.rs[1],
                 exe_if.wrapper_exe_instr_issue.req.rs[2]);
      end
      if (exe_if.exe_wrapper_result.result_valid_exec_o &&
          exe_if.wrapper_exe_recv_result_ready)
        $display("MAC MODEL -> WRAPPER: ID=%0d data=%0d",
                 exe_if.exe_wrapper_result.issue_exec_o.req.id,
                 exe_if.exe_wrapper_result.result_data_exec_o);

      if (result_held)
        check(int'(held_result.id), result_valid && result_data === held_result,
              "result changed while the CPU was not ready");
      result_held = result_valid && !result_ready;
      if (result_held) held_result = result_data;

      if (result_valid && result_ready) begin
        id = int'(result_data.id);
        check(id, id < NUM_INSTRUCTIONS, "unknown result ID");
        check(id, executed[id] && !returned[id], "unexpected or duplicate result");
        check(id, result_data.hartid == HART && result_data.data == expected_result(id) &&
                  result_data.rd == instructions[id][11:7] && result_data.we,
              "wrong result data or destination register");
        returned[id] = 1;
        result_count++;
        $display("WRAPPER -> CPU RESULT: ID=%0d data=%0d rd=%0d we=%b",
                 id, result_data.data, result_data.rd, result_data.we);
      end
    end
  end

  task automatic send_issue(input int id);
    @(negedge clk);
    issue_req = '{instr: instructions[id], hartid: HART, id: id_t'(id)};
    issue_valid = 1;
    $display("CPU -> WRAPPER ISSUE: ID=%0d instruction=0x%08h", id, issue_req.instr);
    repeat (MAX_CYCLES) begin
      @(posedge clk);
      if (issue_ready) break;
    end
    check(id, issue_ready, "issue handshake timeout");
    @(negedge clk);
    issue_valid = 0;
  endtask

  task automatic send_registers(input int id);
    @(negedge clk);
    register_data = '{hartid: HART, id: id_t'(id), rs: operands[id],
                      rs_valid: supported[id] ? 3'b111 : 3'b000};
    register_valid = 1;
    @(posedge clk);
    check(id, register_ready, "register packet was not received");
    @(negedge clk);
    register_valid = 0;
  endtask

  task automatic send_commit(input int id);
    @(negedge clk);
    commit_data = '{hartid: HART, id: id_t'(id), commit_kill: kill_instruction[id]};
    commit_valid = 1;
    @(negedge clk);
    commit_valid = 0;
  endtask

  initial begin
    check(-1, NUM_INSTRUCTIONS > BUFFER_DEPTH, "send more instructions than buffer slots");
    check(-1, NUM_INSTRUCTIONS <= 2 ** $bits(id_t), "not enough ID bits for this test");
    $display("CONFIG: instructions=%0d buffer_depth=%0d id_bits=%0d",
             NUM_INSTRUCTIONS, BUFFER_DEPTH, $bits(id_t));
    issue_req     = '0;
    register_data = '0;
    commit_data   = '0;

    // Fill the buffer first, then mix supported and unsupported instructions
    for (int id = 0; id < NUM_INSTRUCTIONS; id++) begin
      supported[id] = id <= BUFFER_DEPTH || id % 2 == 0 || id == NUM_INSTRUCTIONS - 1;
      kill_instruction[id] = id == NUM_INSTRUCTIONS - 1;
      instructions[id] = supported[id] ?
          32'h0020f00b | (32'((id % 29) + 3) << 7) :
          (id % 4 == 1 ? 32'h00000013 : 32'h0000000f);
      operands[id] = {32'(100 + id), 32'(3 + id), 32'(2 + id)};
      if (supported[id]) expected_accepted++;
      if (supported[id] && !kill_instruction[id]) expected_results++;
    end
    repeat (3) @(negedge clk);
    rst_n = 1;

    fork
      begin
        for (int id = 0; id < NUM_INSTRUCTIONS; id++) send_issue(id);
      end
      begin
        // Keep the next issue waiting before releasing any buffer entry
        repeat (MAX_CYCLES) begin
          @(negedge clk);
          if (stall_cycles >= 3) break;
        end
        check(BUFFER_DEPTH, stall_cycles >= 3 && accepted_count == BUFFER_DEPTH,
              "the full buffer did not hold the next issue");
        $display("BUFFER FULL: stored=%0d waiting_ID=%0d stalled_cycles=%0d",
                 accepted_count, issue_req.id, stall_cycles);

        for (int id = 0; id < NUM_INSTRUCTIONS; id++) begin
          wait (issued[id]);
          if (supported[id] && id % 2 == 1 && !kill_instruction[id]) begin
            send_commit(id);
            send_registers(id);
          end else begin
            send_registers(id);
            send_commit(id);
          end
        end
      end
      begin
        // Let the first result wait before the CPU starts accepting results
        repeat (MAX_CYCLES) begin
          @(negedge clk);
          if (result_valid) break;
        end
        check(0, result_valid, "the first result never arrived");
        repeat (3) @(negedge clk);
        result_ready = 1;
      end
    join

    repeat (MAX_CYCLES) begin
      @(negedge clk);
      if (result_count == expected_results) break;
    end
    check(-1, result_count == expected_results, "missing results");
    repeat (5) @(negedge clk);
    check(-1, !exe_if.wrapper_exe_instr_valid && !result_valid, "extra output after completion");
    check(-1, accepted_count == expected_accepted &&
              accepted_count + rejected_count == NUM_INSTRUCTIONS &&
              register_count == NUM_INSTRUCTIONS &&
              commit_count + kill_count == NUM_INSTRUCTIONS,
          "some input transfers were lost");

    for (int id = 0; id < NUM_INSTRUCTIONS; id++)
      check(id, issued[id] && register_seen[id] && commit_seen[id] &&
                executed[id] == (supported[id] && !kill_instruction[id]) &&
                returned[id] == (supported[id] && !kill_instruction[id]),
            "instruction did not complete its expected path");

    $display("PASS: issues=%0d accepted=%0d rejected=%0d registers=%0d commits=%0d kills=%0d executions=%0d results=%0d",
             accepted_count + rejected_count, accepted_count, rejected_count, register_count,
             commit_count, kill_count, execution_count, result_count);
    $finish;
  end
endmodule
