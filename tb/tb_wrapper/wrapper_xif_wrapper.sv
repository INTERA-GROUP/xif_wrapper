module wrapper_xif_wrapper #(
  parameter int unsigned X_NUM_RS        =  3,  // Number of register file read ports that can be used by the eXtension interface
  parameter int unsigned X_ID_WIDTH      =  4,  // Width of ID field.
  parameter int unsigned X_MEM_WIDTH     =  32, // Memory access width for loads/stores via the eXtension interface
  parameter int unsigned X_RFR_WIDTH     =  32, // Register file read access width for the eXtension interface
  parameter int unsigned X_RFW_WIDTH     =  32, // Register file write access width for the eXtension interface
  parameter logic [31:0] X_MISA          =  '0, // MISA extensions implemented on the eXtension interface
  parameter logic [ 1:0] X_ECS_XS        =  '0  // Default value for mstatus.XS
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
  input  logic                     ext_if_coproc_compressed_valid,
  output logic                    ext_if_coproc_compressed_ready,
  input  logic [15:0]             ext_if_coproc_compressed_req_instr,
  input  logic [1:0]              ext_if_coproc_compressed_req_mode,
  input  logic [X_ID_WIDTH-1:0]   ext_if_coproc_compressed_req_id,
  output logic [31:0]            ext_if_coproc_compressed_resp_instr,
  output logic                   ext_if_coproc_compressed_resp_accept,

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

  // MEMORY IF
  output logic                    ext_if_coproc_mem_valid,
  input  logic                    ext_if_coproc_mem_ready,
  output logic [X_ID_WIDTH-1:0]   ext_if_coproc_mem_req_id,
  output logic [31:0]             ext_if_coproc_mem_req_addr,
  output logic [1:0]              ext_if_coproc_mem_req_mode,
  output logic                    ext_if_coproc_mem_req_we,
  output logic [2:0]              ext_if_coproc_mem_req_size,
  output logic [X_MEM_WIDTH/8-1:0] ext_if_coproc_mem_req_be,
  output logic [1:0]              ext_if_coproc_mem_req_attr,
  output logic [X_MEM_WIDTH-1:0]  ext_if_coproc_mem_req_wdata,
  output logic                    ext_if_coproc_mem_req_last,
  output logic                    ext_if_coproc_mem_req_spec,
  input  logic                    ext_if_coproc_mem_resp_exc,
  input  logic [5:0]              ext_if_coproc_mem_resp_exccode,
  input  logic                    ext_if_coproc_mem_resp_dbg,

  // MEMORY RESULT IF
  input  logic                    ext_if_coproc_mem_result_valid,
  input  logic [X_ID_WIDTH-1:0]   ext_if_coproc_mem_result_id,
  input  logic [X_MEM_WIDTH-1:0]  ext_if_coproc_mem_result_rdata,
  input  logic                    ext_if_coproc_mem_result_err,
  input  logic                    ext_if_coproc_mem_result_dbg,

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
  input logic                   exe_wrapper_result_issue_exec_o_resp_exc
  

);

  x_issue_t wrapper_exe_instr_issue;
  x_issue_fifo_res_t exe_wrapper_result;

  if_xif #(
      .X_NUM_RS(X_NUM_RS),
      .X_ID_WIDTH(X_ID_WIDTH),
      .X_MEM_WIDTH(X_MEM_WIDTH),
      .X_RFR_WIDTH(X_RFR_WIDTH),
      .X_RFW_WIDTH(X_RFW_WIDTH),
      .X_MISA(X_MISA),
      .X_ECS_XS(X_ECS_XS)  // Default value for mstatus.XS
  ) ext_if ();

    if_xif_exe xif_exe_inst();


//   modport coproc_compressed (
//     input  compressed_valid,
//     output compressed_ready,
//     input  compressed_req,
//     output compressed_resp
//   );

// Compressed interface
  assign ext_if.compressed_valid            = ext_if_coproc_compressed_valid;
  assign ext_if_coproc_compressed_ready     = ext_if.compressed_ready;
  assign ext_if.compressed_req.instr        = ext_if_coproc_compressed_req_instr;
  assign ext_if.compressed_req.mode         = ext_if_coproc_compressed_req_mode;
  assign ext_if.compressed_req.id           = ext_if_coproc_compressed_req_id;
  assign ext_if_coproc_compressed_resp_instr = ext_if.compressed_resp.instr;
  assign ext_if_coproc_compressed_resp_accept = ext_if.compressed_resp.accept;

  // Issue interface
  assign ext_if.issue_valid                 = ext_if_coproc_issue_valid;
  assign ext_if_coproc_issue_ready          = ext_if.issue_ready;
  assign ext_if.issue_req.instr             = ext_if_coproc_issue_req_instr;
  assign ext_if.issue_req.mode              = ext_if_coproc_issue_req_mode;
  assign ext_if.issue_req.id                = ext_if_coproc_issue_req_id;
  assign ext_if.issue_req.rs                = ext_if_coproc_issue_req_rs;
  assign ext_if.issue_req.rs_valid          = ext_if_coproc_issue_req_rs_valid;
  assign ext_if.issue_req.ecs               = ext_if_coproc_issue_req_ecs;
  assign ext_if.issue_req.ecs_valid         = ext_if_coproc_issue_req_ecs_valid;
  assign ext_if_coproc_issue_resp_accept    = ext_if.issue_resp.accept;
  assign ext_if_coproc_issue_resp_writeback = ext_if.issue_resp.writeback;
  assign ext_if_coproc_issue_resp_dualwrite = ext_if.issue_resp.dualwrite;
  assign ext_if_coproc_issue_resp_dualread  = ext_if.issue_resp.dualread;
  assign ext_if_coproc_issue_resp_loadstore = ext_if.issue_resp.loadstore;
  assign ext_if_coproc_issue_resp_ecswrite  = ext_if.issue_resp.ecswrite;
  assign ext_if_coproc_issue_resp_exc       = ext_if.issue_resp.exc;

  // Commit interface
  assign ext_if.commit_valid                = ext_if_coproc_commit_valid;
  assign ext_if.commit.id                   = ext_if_coproc_commit_id;
  assign ext_if.commit.commit_kill          = ext_if_coproc_commit_kill;

  // Memory interface
  assign ext_if_coproc_mem_valid            = ext_if.mem_valid;
  assign ext_if.mem_ready                   = ext_if_coproc_mem_ready;
  assign ext_if.mem_req.id                  = ext_if_coproc_mem_req_id;
  assign ext_if.mem_req.addr                = ext_if_coproc_mem_req_addr;
  assign ext_if.mem_req.mode                = ext_if_coproc_mem_req_mode;
  assign ext_if.mem_req.we                  = ext_if_coproc_mem_req_we;
  assign ext_if.mem_req.size                = ext_if_coproc_mem_req_size;
  assign ext_if.mem_req.be                  = ext_if_coproc_mem_req_be;
  assign ext_if.mem_req.attr                = ext_if_coproc_mem_req_attr;
  assign ext_if.mem_req.wdata               = ext_if_coproc_mem_req_wdata;
  assign ext_if.mem_req.last                = ext_if_coproc_mem_req_last;
  assign ext_if.mem_req.spec                = ext_if_coproc_mem_req_spec;

  assign ext_if.mem_resp.exc         = ext_if_coproc_mem_resp_exc;
  assign ext_if.mem_resp.exccode     = ext_if_coproc_mem_resp_exccode;
  assign ext_if.mem_resp.dbg         = ext_if_coproc_mem_resp_dbg;

  // Memory result interface
  assign ext_if.mem_result_valid            = ext_if_coproc_mem_result_valid;
  assign ext_if.mem_result.id               = ext_if_coproc_mem_result_id;
  assign ext_if.mem_result.rdata            = ext_if_coproc_mem_result_rdata;
  assign ext_if.mem_result.err              = ext_if_coproc_mem_result_err;
  assign ext_if.mem_result.dbg              = ext_if_coproc_mem_result_dbg;

  // Result interface
  assign ext_if_coproc_result_valid         = ext_if.result_valid;
  assign ext_if.result_ready                = ext_if_coproc_result_ready;
  assign ext_if_coproc_result_id = ext_if.result.id;
  assign ext_if_coproc_result_data = ext_if.result.data;
  assign ext_if_coproc_result_rd = ext_if.result.rd;
  assign ext_if_coproc_result_we = ext_if.result.we;
  assign ext_if_coproc_result_ecsdata = ext_if.result.ecsdata;
  assign ext_if_coproc_result_ecswe = ext_if.result.ecswe;
  assign ext_if_coproc_result_exc = ext_if.result.exc;
  assign ext_if_coproc_result_exccode = ext_if.result.exccode;
  assign ext_if_coproc_result_err = ext_if.result.err;
  assign ext_if_coproc_result_dbg = ext_if.result.dbg;

  assign wrapper_exe_instr_valid =  xif_exe_inst.wrapper_exe_instr_valid;
  assign wrapper_exe_instr_issue = xif_exe_inst.wrapper_exe_instr_issue;

  
  assign wrapper_exe_instr_issue_req_instr = wrapper_exe_instr_issue.req.instr;
  assign wrapper_exe_instr_issue_req_mode = wrapper_exe_instr_issue.req.mode;
  assign wrapper_exe_instr_issue_req_id = wrapper_exe_instr_issue.req.id;
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
      // Module with custom instruction
      
    xif_wrapper #(
          // .NbInstr(NbInstr),
          // .CoproInstr(CoproInstr),
          // .X_NUM_RS(X_NUM_RS)
           ) xif_wrapper_inst (
          // Clock and reset
          .clk_i (clk_i),
          .rst_ni(rst_ni),

          // eXtension Interface
          .xif_compressed_if(ext_if.coproc_compressed),
          .xif_issue_if(ext_if.coproc_issue),
          .xif_commit_if(ext_if.coproc_commit),
          .xif_mem_if(ext_if.coproc_mem),
          .xif_mem_result_if(ext_if.coproc_mem_result),
          .xif_result_if(ext_if.coproc_result),
          .if_wrapper_exe(xif_exe_inst.xif_wrapper)
      );
    
endmodule
