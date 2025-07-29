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
  output logic                    ext_if_coproc_result_dbg



);



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
  assign ext_if.result.id                   = ext_if_coproc_result_id;
  assign ext_if.result.data                 = ext_if_coproc_result_data;
  assign ext_if.result.rd                   = ext_if_coproc_result_rd;
  assign ext_if.result.we                   = ext_if_coproc_result_we;
  assign ext_if.result.ecsdata              = ext_if_coproc_result_ecsdata;
  assign ext_if.result.ecswe                = ext_if_coproc_result_ecswe;
  assign ext_if.result.exc                  = ext_if_coproc_result_exc;
  assign ext_if.result.exccode              = ext_if_coproc_result_exccode;
  assign ext_if.result.err                  = ext_if_coproc_result_err;
  assign ext_if.result.dbg                  = ext_if_coproc_result_dbg;


    
      // Module with custom instruction
      
    xif_wrapper  xif_wrapper_inst (
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
