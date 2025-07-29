import cvxif_instr_pkg::*;

interface if_xif_exe;


// instruction issue signal

logic wrapper_exe_instr_vaild;      // instruction vaild
x_issue_t wrapper_exe_instr_issue;      // instruction issued
logic exe_wrapper_recv_instr_ready;            // exe block is ready to receive new instruction

logic wrapper_exe_recv_result_ready;
x_issue_fifo_res_t exe_wrapper_result;

  modport exe_unit (
  input wrapper_exe_instr_vaild,
  input wrapper_exe_instr_issue,
  output exe_wrapper_recv_instr_ready,
  input wrapper_exe_recv_result_ready,
  output exe_wrapper_result
  );

  modport xif_wrapper (
  output wrapper_exe_instr_vaild,
  output wrapper_exe_instr_issue,
  input exe_wrapper_recv_instr_ready,
  output wrapper_exe_recv_result_ready,
  input exe_wrapper_result
  );

endinterface //if_xif_exe
