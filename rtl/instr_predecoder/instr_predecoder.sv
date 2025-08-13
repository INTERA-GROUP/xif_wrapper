// Author: Gonzalo Salinas Hernando <gonzalo.salinas@nvision.es>
// Description: Instruction PRE-DECODER for the copro in the x-if interface
// This module provides a combinational resp to instr. req based on the OPCODE

module instr_predecoder
import cvxif_instr_pkg::*;
#(

) (
  input  logic          clk_i,
  input  logic          issue_valid_i,
  input  logic          issue_ready_i,  
  input  x_issue_req_t  x_issue_req_i,
  output x_issue_resp_t x_issue_resp_o,
  output logic [X_NUM_RS-1:0]    rs_valid_mask
);

logic [NbInstr-1:0] sel; //Selector 

for (genvar i = 0; i < NbInstr; i++) begin : gen_predecoder_selector
  assign sel[i] = ((CoproInstr[i].mask & x_issue_req_i.instr) == CoproInstr[i].instr); // Raise selector when instruction matches with OPCODES supported by copro
end

always_comb begin
  x_issue_resp_o.accept    = '0;
  x_issue_resp_o.writeback = '0;
  x_issue_resp_o.dualwrite = '0;
  x_issue_resp_o.dualread  = '0;
  x_issue_resp_o.ecswrite  = '0;
  x_issue_resp_o.exc       = '0;
  rs_valid_mask            = '0;
  for (int unsigned i = 0; i < NbInstr; i++) begin //TODO: Modify the condition below "issue_ready_i && x_issue_req_i.rs_valid == '1" -> This condition can be erased as it is already checked for issue_ready? What about issue_valid_i?? -> (only sel[i])?
    if (sel[i]) begin //&& issue_valid_i && issue_ready_i && x_issue_req_i.rs_valid == '1 // x_issue_req_i.rs_valid='1 for the moment we consider all instr use all source registers, so they must all be valid
      if (issue_valid_i == 1) begin
      x_issue_resp_o.accept    = CoproInstr[i].resp.accept;
      x_issue_resp_o.writeback = CoproInstr[i].resp.writeback;
      x_issue_resp_o.dualwrite = CoproInstr[i].resp.dualwrite;
      x_issue_resp_o.dualread  = CoproInstr[i].resp.dualread;
      x_issue_resp_o.loadstore = CoproInstr[i].resp.loadstore;
      x_issue_resp_o.ecswrite  = CoproInstr[i].resp.ecswrite;
      x_issue_resp_o.exc       = CoproInstr[i].resp.exc;
      rs_valid_mask            = CoproInstr[i].rs_valid_mask;
      end
    end
  end
end

assert property (@(posedge clk_i) $onehot0(sel))
else $warning("This offloaded instruction is valid for multiple coprocessor instructions !");

endmodule
