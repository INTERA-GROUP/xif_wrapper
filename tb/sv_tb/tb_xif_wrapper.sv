module tb_xif_wrapper (
);

logic clk_i;
logic rst_ni;

  if_xif #(
      .X_NUM_RS(3),
      .X_ID_WIDTH(4),
      .X_MEM_WIDTH(32),
      .X_RFR_WIDTH(32),
      .X_RFW_WIDTH(32),
      .X_MISA('0),
      .X_ECS_XS('0)  // Default value for mstatus.XS
  ) ext_if ();

    if_xif_exe xif_exe_inst();
    
      // Module with custom instruction
      
    xif_wrapper #() xif_wrapper_inst (
          // Clock and reset
          .clk_i (clk_i),
          .rst_ni(rst_ni),

          // eXtension Interface
          .xif_compressed_if(ext_if),
          .xif_issue_if(ext_if),
          .xif_commit_if(ext_if),
          .xif_mem_if(ext_if),
          .xif_mem_result_if(ext_if),
          .xif_result_if(ext_if),
          .if_wrapper_exe(xif_exe_inst.xif_wrapper)
      );
    
endmodule
