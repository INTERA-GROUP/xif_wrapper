module wrapper_xif_wrapper #(
  parameter int unsigned X_NUM_RS        = cvxif_instr_pkg::X_NUM_RS,  // Number of register file read ports that can be used by the eXtension interface
  parameter int unsigned X_ID_WIDTH      = cvxif_instr_pkg::X_ID_WIDTH, // Width of ID field.
  parameter int unsigned X_MEM_WIDTH     =  32, // Memory access width for loads/stores via the eXtension interface
  parameter int unsigned X_RFR_WIDTH     = cvxif_instr_pkg::X_RFR_WIDTH, // Register file read access width for the eXtension interface
  parameter int unsigned X_RFW_WIDTH     = cvxif_instr_pkg::X_RFW_WIDTH, // Register file write access width for the eXtension interface
  parameter logic [31:0] X_MISA          =  '0, // MISA extensions implemented on the eXtension interface
  parameter logic [ 1:0] X_ECS_XS        =  '0, // Default value for mstatus.XS
  parameter int unsigned X_HARTID_WIDTH = cvxif_instr_pkg::X_HARTID_WIDTH
)  ( 
input logic clk_i,
input logic rst_ni,
//   modport coproc_compressed (
//     input  compressed_valid,
//     output compressed_ready,
//     input  compressed_req,
//     output compressed_resp
//   );

// COMPRESSED IF
  // input  logic                     ext_if_coproc_compressed_valid,
  // output logic                    ext_if_coproc_compressed_ready,
  // input  logic [15:0]             ext_if_coproc_compressed_req_instr,
  // input  logic [1:0]              ext_if_coproc_compressed_req_mode,
  // input  logic [X_ID_WIDTH-1:0]   ext_if_coproc_compressed_req_id,
  // output logic [31:0]            ext_if_coproc_compressed_resp_instr,
  // output logic                   ext_if_coproc_compressed_resp_accept,

  // ISSUE IF
  input  logic                     ext_if_coproc_issue_valid,
  output logic                    ext_if_coproc_issue_ready,
  
  input  logic [31:0]             ext_if_coproc_issue_req_instr,
  input  logic [1:0]              ext_if_coproc_issue_req_mode,
  input  logic [X_ID_WIDTH-1:0]   ext_if_coproc_issue_req_id,
  input  logic [X_NUM_RS-1:0][X_RFR_WIDTH-1:0] ext_if_coproc_issue_req_rs,
  input  logic [(X_RFR_WIDTH/32)*X_NUM_RS-1:0] ext_if_coproc_issue_req_rs_valid,
  input  logic [5:0]              ext_if_coproc_issue_req_ecs,
  input  logic                    ext_if_coproc_issue_req_ecs_valid,

  output logic                    ext_if_coproc_issue_resp_accept,
  output logic                    ext_if_coproc_issue_resp_writeback,
  output logic                    ext_if_coproc_issue_resp_dualwrite,
  output logic [2:0]              ext_if_coproc_issue_resp_dualread,
  output logic                    ext_if_coproc_issue_resp_loadstore,
  output logic                    ext_if_coproc_issue_resp_ecswrite,
  output logic                    ext_if_coproc_issue_resp_exc,

  // COMMIT IF
  input  logic                    ext_if_coproc_commit_valid,
  input  logic [X_ID_WIDTH-1:0]   ext_if_coproc_commit_id,
  input  logic                    ext_if_coproc_commit_kill,

  // // MEMORY IF
  // output logic                    ext_if_coproc_mem_valid,
  // input  logic                    ext_if_coproc_mem_ready,
  // output logic [X_ID_WIDTH-1:0]   ext_if_coproc_mem_req_id,
  // output logic [31:0]             ext_if_coproc_mem_req_addr,
  // output logic [1:0]              ext_if_coproc_mem_req_mode,
  // output logic                    ext_if_coproc_mem_req_we,
  // output logic [2:0]              ext_if_coproc_mem_req_size,
  // output logic [X_MEM_WIDTH/8-1:0] ext_if_coproc_mem_req_be,
  // output logic [1:0]              ext_if_coproc_mem_req_attr,
  // output logic [X_MEM_WIDTH-1:0]  ext_if_coproc_mem_req_wdata,
  // output logic                    ext_if_coproc_mem_req_last,
  // output logic                    ext_if_coproc_mem_req_spec,
  // input  logic                    ext_if_coproc_mem_resp_exc,
  // input  logic [5:0]              ext_if_coproc_mem_resp_exccode,
  // input  logic                    ext_if_coproc_mem_resp_dbg,

  // // MEMORY RESULT IF
  // input  logic                    ext_if_coproc_mem_result_valid,
  // input  logic [X_ID_WIDTH-1:0]   ext_if_coproc_mem_result_id,
  // input  logic [X_MEM_WIDTH-1:0]  ext_if_coproc_mem_result_rdata,
  // input  logic                    ext_if_coproc_mem_result_err,
  // input  logic                    ext_if_coproc_mem_result_dbg,

  // RESULT IF
  output logic                    ext_if_coproc_result_valid,
  input  logic                    ext_if_coproc_result_ready,
  output logic [X_ID_WIDTH-1:0]   ext_if_coproc_result_id,
  output logic [X_RFW_WIDTH-1:0]  ext_if_coproc_result_data,
  output logic [4:0]              ext_if_coproc_result_rd,
  output logic [X_RFW_WIDTH/32-1:0] ext_if_coproc_result_we,
  output logic [5:0]              ext_if_coproc_result_ecsdata,
  output logic [2:0]              ext_if_coproc_result_ecswe,
  output logic                    ext_if_coproc_result_exc,
  output logic [5:0]              ext_if_coproc_result_exccode,
  output logic                    ext_if_coproc_result_err,
  output logic                    ext_if_coproc_result_dbg,

  output  logic wrapper_exe_instr_valid,
  output  logic [31:0]            wrapper_exe_instr_issue_req_instr,
  output  logic [1:0]             wrapper_exe_instr_issue_req_mode,
  output  logic [X_ID_WIDTH-1:0]  wrapper_exe_instr_issue_req_id,
  output  logic [X_NUM_RS-1:0][X_RFR_WIDTH-1:0]wrapper_exe_instr_issue_req_rs,
  output  logic [(X_RFR_WIDTH/32)*X_NUM_RS-1:0]wrapper_exe_instr_issue_req_rs_valid,
  output  logic [5:0]             wrapper_exe_instr_issue_req_ecs,
  output  logic                   wrapper_exe_instr_issue_req_ecs_valid,

  output logic                   wrapper_exe_instr_issue_resp_accept,
  output logic                   wrapper_exe_instr_issue_resp_writeback,
  output logic                   wrapper_exe_instr_issue_resp_dualwrite,
  output logic [2:0]             wrapper_exe_instr_issue_resp_dualread,
  output logic                   wrapper_exe_instr_issue_resp_loadstore,
  output logic                   wrapper_exe_instr_issue_resp_ecswrite,
  output logic                   wrapper_exe_instr_issue_resp_exc,
  input logic exe_wrapper_recv_instr_ready,
  output logic wrapper_exe_recv_result_ready,

  input  logic [X_RFW_WIDTH     -1:0] exe_wrapper_result_result_data_exec_o,
  input  logic                    exe_wrapper_result_result_valid_exec_o,
  input  logic [31:0]            exe_wrapper_result_issue_exec_o_req_instr,
  input  logic [1:0]             exe_wrapper_result_issue_exec_o_req_mode,
  input  logic [X_ID_WIDTH-1:0]  exe_wrapper_result_issue_exec_o_req_id,
  input  logic [X_NUM_RS-1:0][X_RFR_WIDTH-1:0]exe_wrapper_result_issue_exec_o_req_rs,
  input  logic [(X_RFR_WIDTH/32)*X_NUM_RS-1:0]exe_wrapper_result_issue_exec_o_req_rs_valid,
  input  logic [5:0]             exe_wrapper_result_issue_exec_o_req_ecs,
  input  logic                   exe_wrapper_result_issue_exec_o_req_ecs_valid,
  input logic                   exe_wrapper_result_issue_exec_o_resp_accept,
  input logic                   exe_wrapper_result_issue_exec_o_resp_writeback,
  input logic                   exe_wrapper_result_issue_exec_o_resp_dualwrite,
  input logic [2:0]             exe_wrapper_result_issue_exec_o_resp_dualread,
  input logic                   exe_wrapper_result_issue_exec_o_resp_loadstore,
  input logic                   exe_wrapper_result_issue_exec_o_resp_ecswrite,
  input logic                   exe_wrapper_result_issue_exec_o_resp_exc,

  // CV-X-IF v1.0 ports - Maryana Pyzh
  input  logic [X_HARTID_WIDTH-1:0] ext_if_coproc_issue_req_hartid,
  output cvxif_instr_pkg::readregflags_t ext_if_coproc_issue_resp_register_read,
  input  logic ext_if_coproc_register_valid,
  output logic ext_if_coproc_register_ready,
  input  logic [X_HARTID_WIDTH-1:0] ext_if_coproc_register_hartid,
  input  logic [X_ID_WIDTH-1:0] ext_if_coproc_register_id,
  input  logic [X_NUM_RS-1:0][X_RFR_WIDTH-1:0] ext_if_coproc_register_rs,
  input  cvxif_instr_pkg::readregflags_t ext_if_coproc_register_rs_valid,
  input  logic [X_HARTID_WIDTH-1:0] ext_if_coproc_commit_hartid,
  output logic [X_HARTID_WIDTH-1:0] ext_if_coproc_result_hartid,
  output logic [X_HARTID_WIDTH-1:0] wrapper_exe_instr_issue_req_hartid,
  input  logic [X_HARTID_WIDTH-1:0] exe_wrapper_result_issue_exec_o_req_hartid
  

);

  import cvxif_instr_pkg::*;

  x_issue_t wrapper_exe_instr_issue;
  x_issue_fifo_res_t exe_wrapper_result;
  x_issue_req_v1_t issue_req;
  x_issue_resp_v1_t issue_resp;
  x_register_v1_t register_data;
  x_commit_v1_t commit_data;
  x_result_v1_t result_data;
  if_xif_exe xif_exe_inst();

  // Each CPU channel carries its own instruction ID and hart ID
  assign issue_req = '{
    instr: ext_if_coproc_issue_req_instr,
    hartid: ext_if_coproc_issue_req_hartid,
    id: ext_if_coproc_issue_req_id
  };
  assign register_data = '{
    hartid: ext_if_coproc_register_hartid,
    id: ext_if_coproc_register_id,
    rs: ext_if_coproc_register_rs,
    rs_valid: ext_if_coproc_register_rs_valid
  };
  assign commit_data = '{
    hartid: ext_if_coproc_commit_hartid,
    id: ext_if_coproc_commit_id,
    commit_kill: ext_if_coproc_commit_kill
  };

  assign ext_if_coproc_issue_resp_accept = issue_resp.accept;
  assign ext_if_coproc_issue_resp_writeback = issue_resp.writeback;
  assign ext_if_coproc_issue_resp_register_read = issue_resp.register_read;
  assign ext_if_coproc_result_hartid = result_data.hartid;
  assign ext_if_coproc_result_id = result_data.id;
  assign ext_if_coproc_result_data = result_data.data;
  assign ext_if_coproc_result_rd = result_data.rd;
  assign ext_if_coproc_result_we = result_data.we;

  // Keep the old signal names for the Python tests
  // Fields absent from the v1.0 CPU packets stay at zero
  assign ext_if_coproc_issue_resp_dualwrite = '0;
  assign ext_if_coproc_issue_resp_dualread = '0;
  assign ext_if_coproc_issue_resp_loadstore = '0;
  assign ext_if_coproc_issue_resp_ecswrite = '0;
  assign ext_if_coproc_issue_resp_exc = '0;
  assign ext_if_coproc_result_ecsdata = '0;
  assign ext_if_coproc_result_ecswe = '0;
  assign ext_if_coproc_result_exc = '0;
  assign ext_if_coproc_result_exccode = '0;
  assign ext_if_coproc_result_err = '0;
  assign ext_if_coproc_result_dbg = '0;

  assign wrapper_exe_instr_valid =  xif_exe_inst.wrapper_exe_instr_valid;
  assign wrapper_exe_instr_issue = xif_exe_inst.wrapper_exe_instr_issue;

  
  assign wrapper_exe_instr_issue_req_instr = wrapper_exe_instr_issue.req.instr;
  assign wrapper_exe_instr_issue_req_mode = wrapper_exe_instr_issue.req.mode;
  assign wrapper_exe_instr_issue_req_id = wrapper_exe_instr_issue.req.id;
  assign wrapper_exe_instr_issue_req_hartid = wrapper_exe_instr_issue.req.hartid;
  assign wrapper_exe_instr_issue_req_rs = wrapper_exe_instr_issue.req.rs;
  assign wrapper_exe_instr_issue_req_rs_valid = wrapper_exe_instr_issue.req.rs_valid;
  assign wrapper_exe_instr_issue_req_ecs = wrapper_exe_instr_issue.req.ecs;
  assign wrapper_exe_instr_issue_req_ecs_valid = wrapper_exe_instr_issue.req.ecs_valid;
  assign wrapper_exe_instr_issue_resp_accept = wrapper_exe_instr_issue.resp.accept;
  assign wrapper_exe_instr_issue_resp_writeback = wrapper_exe_instr_issue.resp.writeback;
  assign wrapper_exe_instr_issue_resp_dualwrite = wrapper_exe_instr_issue.resp.dualwrite;
  assign wrapper_exe_instr_issue_resp_dualread = wrapper_exe_instr_issue.resp.dualread;
  assign wrapper_exe_instr_issue_resp_loadstore = wrapper_exe_instr_issue.resp.loadstore;
  assign wrapper_exe_instr_issue_resp_ecswrite = wrapper_exe_instr_issue.resp.ecswrite;
  assign wrapper_exe_instr_issue_resp_exc = wrapper_exe_instr_issue.resp.exc;

  assign xif_exe_inst.exe_wrapper_recv_instr_ready = exe_wrapper_recv_instr_ready;
  assign wrapper_exe_recv_result_ready = xif_exe_inst.wrapper_exe_recv_result_ready;

  assign exe_wrapper_result.result_data_exec_o = exe_wrapper_result_result_data_exec_o;
  assign exe_wrapper_result.result_valid_exec_o = exe_wrapper_result_result_valid_exec_o;
  assign exe_wrapper_result.issue_exec_o.req.instr = exe_wrapper_result_issue_exec_o_req_instr;
  assign exe_wrapper_result.issue_exec_o.req.mode = exe_wrapper_result_issue_exec_o_req_mode;
  assign exe_wrapper_result.issue_exec_o.req.id = exe_wrapper_result_issue_exec_o_req_id;
  assign exe_wrapper_result.issue_exec_o.req.hartid = exe_wrapper_result_issue_exec_o_req_hartid;
  assign exe_wrapper_result.issue_exec_o.req.rs = exe_wrapper_result_issue_exec_o_req_rs;
  assign exe_wrapper_result.issue_exec_o.req.rs_valid = exe_wrapper_result_issue_exec_o_req_rs_valid;
  assign exe_wrapper_result.issue_exec_o.req.ecs = exe_wrapper_result_issue_exec_o_req_ecs;
  assign exe_wrapper_result.issue_exec_o.req.ecs_valid = exe_wrapper_result_issue_exec_o_req_ecs_valid;
  assign exe_wrapper_result.issue_exec_o.resp.accept = exe_wrapper_result_issue_exec_o_resp_accept;
  assign exe_wrapper_result.issue_exec_o.resp.writeback = exe_wrapper_result_issue_exec_o_resp_writeback;
  assign exe_wrapper_result.issue_exec_o.resp.dualwrite = exe_wrapper_result_issue_exec_o_resp_dualwrite;
  assign exe_wrapper_result.issue_exec_o.resp.dualread = exe_wrapper_result_issue_exec_o_resp_dualread;
  assign exe_wrapper_result.issue_exec_o.resp.loadstore = exe_wrapper_result_issue_exec_o_resp_loadstore;
  assign exe_wrapper_result.issue_exec_o.resp.ecswrite = exe_wrapper_result_issue_exec_o_resp_ecswrite;
  assign exe_wrapper_result.issue_exec_o.resp.exc = exe_wrapper_result_issue_exec_o_resp_exc;

  assign xif_exe_inst.exe_wrapper_result = exe_wrapper_result;
  xif_wrapper xif_wrapper_inst (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .x_issue_req_i(issue_req),
    .x_issue_resp_o(issue_resp),
    .x_issue_valid_i(ext_if_coproc_issue_valid),
    .x_issue_ready_o(ext_if_coproc_issue_ready),
    .x_register_i(register_data),
    .x_register_valid_i(ext_if_coproc_register_valid),
    .x_register_ready_o(ext_if_coproc_register_ready),
    .x_commit_i(commit_data),
    .x_commit_valid_i(ext_if_coproc_commit_valid),
    .x_result_o(result_data),
    .x_result_valid_o(ext_if_coproc_result_valid),
    .x_result_ready_i(ext_if_coproc_result_ready),
    .if_wrapper_exe(xif_exe_inst.xif_wrapper)
  );
endmodule
