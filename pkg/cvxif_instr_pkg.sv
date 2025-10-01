// Author: Gonzalo Salinas Hernando <gonzalo.salinas@nvision.es>
// Description: Package required for the co-pro in the x-if interface
// Includes handy structures, some parameters and the resp to instr. req

package cvxif_instr_pkg;

localparam X_NUM_RS = 3;  //2 or 3
localparam X_ID_WIDTH = 4; // Number of bits for the instr. ID - This could match the INSTR_DEPTH of FIFO_INST

`ifdef XIF_X_RFR_WIDTH
    localparam X_RFR_WIDTH = `XIF_X_RFR_WIDTH; //Port for src read. Modify if double read: 64
`else
    localparam X_RFR_WIDTH = 32;
`endif

`ifdef XIF_DUAL_REG_READ_CFG
    localparam logic XIF_DUAL_REG_READ = 1; //enable for dual enable and disable
`else
    localparam logic XIF_DUAL_REG_READ = 0;
`endif

localparam X_RFW_WIDTH = 32; //Port for dest write. Modify if double write: 64

// import cvxif_instr_pkg::*;

typedef struct packed {
    logic [          31:0]                  instr;     // Offloaded instruction
    logic [           1:0]                  mode;      // Privilege level
    logic [X_ID_WIDTH-1:0]                  id;        // Identification of the offloaded instruction
    logic [X_NUM_RS  -1:0][X_RFR_WIDTH-1:0] rs;        // Register file source operands for the offloaded instruction
    logic [(X_NUM_RS << XIF_DUAL_REG_READ)  -1:0]                  rs_valid;  // Validity of the register file source operand(s)
    logic [           5:0]                  ecs;       // Extension Context Status ({mstatus.xs, mstatus.fs, mstatus.vs})
    logic                                   ecs_valid; // Validity of the Extension Context Status
} x_issue_req_t;

typedef struct packed {
    logic       accept;     // Is the offloaded instruction (id) accepted by the coprocessor?
    logic       writeback;  // Will the coprocessor perform a writeback in the core to rd?
    logic       dualwrite;  // Will the coprocessor perform a dual writeback in the core to rd and rd+1?
    logic [2:0] dualread;   // Will the coprocessor require dual reads: from rs1\rs2\rs3 and rs1+1\rs2+1\rs3+1?
    logic       loadstore;  // Is the offloaded instruction a load/store instruction?
    logic       ecswrite ;  // Will the coprocessor write the Extension Context Status in mstatus?
    logic       exc;        // Can the offloaded instruction possibly cause a synchronous exception in the coprocessor itself?
} x_issue_resp_t;

// FIFO packed signals - We will input req and resp per instr
typedef struct packed {
    x_issue_req_t  req;
    x_issue_resp_t resp;
  } x_issue_t;

  // Structure for PRE-DECODER
typedef struct packed {
  logic [31:0]              instr;
  logic [31:0]              mask;
  logic [(X_NUM_RS<< XIF_DUAL_REG_READ)-1:0]    rs_valid_mask;
  x_issue_resp_t            resp;
} copro_issue_resp_t;

// FIFO result packed signals
typedef struct packed{
    logic [X_RFW_WIDTH     -1:0]    result_data_exec_o; // Result data from execution block
    logic                           result_valid_exec_o; // Result valid from execution block //TODO: not necessary
    x_issue_t                       issue_exec_o; //Output from execution block
}x_issue_fifo_res_t; 


parameter int unsigned NbInstr_def = 6;

parameter copro_issue_resp_t CoproInstr_def[NbInstr_def] = '{
    /*  Custom Instructions Encoding
    *
    *   |31         25|24     20|19     15|14 12|11      7|6           0|
    *   +-------------+---------+---------+-----+---------+-------------+
    *   |    func7    |   rs2   |   rs1   |func3|   rd    |   opcode    | Instruction
    *   +-------------+---------+---------+-----+---------+-------------+-------------
    *   |0 0 0 0 0 0 0 0 0 0 0 0|   rs1   |0 1 0|   md    |  CUSTOM_x   | mlpload  md, rs1
    *   +-+---+---+-+-+---------+---------+-----+---------+-------------+
    *   |0|wid|wid|d|0|   rs2   |   rs1   |0 1 1|   md    |  CUSTOM_x   | mlpmac<wid>[x<wid>][d]  md, rs1, rs2
    *   +-+---+---+-+-+---------+---------+-----+---------+-------------+
    *   |c|wid|sat|d|   shift   |   ms1   |1 0 0|   rd    |  CUSTOM_x   | mlpread[c]<wid>[d][<sat>] rd, ms1, shift
    *   +-+---+---+-+-----------+---------+-----+---------+-------------+
    *
    */
    '{
        instr: 32'b0000000_00000_00000_010_00000_0001011,  // mlpload  md, rs1
        mask:  32'b1111111_11111_00000_111_00000_1111111,   
        rs_valid_mask: 3'b001, 
        resp : '{
            accept : 1'b1,
            writeback : 1'b0,
            dualwrite : 1'b0,
            dualread : '0,
            loadstore : 1'b0,
            ecswrite : 1'b0,
            exc : 1'b0
        }
    },
    '{
        instr: 32'b0000000_00000_00000_011_00000_0001011,  // mlpmac<00>[x<wid>][0]  md, rs1, rs2; 4-bit
        mask:  32'b1111111_00000_00000_111_00000_1111111,   
        rs_valid_mask: 3'b011, 
        resp : '{
            accept : 1'b1,
            writeback : 1'b0,
            dualwrite : 1'b0,
            dualread : '0,
            loadstore : 1'b0,
            ecswrite : 1'b0,
            exc : 1'b0
        }
    },
    '{
        instr: 32'b0010100_00000_00000_011_00000_0001011,  // mlpmac<01>[x<wid>][0]  md, rs1, rs2; 8-bit
        mask:  32'b1111111_00000_00000_111_00000_1111111,   
        rs_valid_mask: 3'b011, 
        resp : '{
            accept : 1'b1,
            writeback : 1'b0,
            dualwrite : 1'b0,
            dualread : '0,
            loadstore : 1'b0,
            ecswrite : 1'b0,
            exc : 1'b0
        }
    },
    '{
        instr: 32'b0101000_00000_00000_011_00000_0001011,  // mlpmac<10>[x<wid>][0]  md, rs1, rs2; 16-bit
        mask:  32'b1111111_00000_00000_111_00000_1111111,   
        rs_valid_mask: 3'b011, 
        resp : '{
            accept : 1'b1,
            writeback : 1'b0,
            dualwrite : 1'b0,
            dualread : '0,
            loadstore : 1'b0,
            ecswrite : 1'b0,
            exc : 1'b0
        }
    },
    '{
        instr: 32'b0000000_00000_00000_100_00000_0001011,  // mlpread[0]<wid>[0][<sat>] rd, ms1, shift; Read (o-32b)
        mask:  32'b1000000_00000_00000_111_00000_1111111,   
        rs_valid_mask: 3'b000, 
        resp : '{
            accept : 1'b1,
            writeback : 1'b1,
            dualwrite : 1'b0,
            dualread : '0,
            loadstore : 1'b0,
            ecswrite : 1'b0,
            exc : 1'b0
        }
    },
    '{
        instr: 32'b1000000_00000_00000_100_00000_0001011,  // mlpread[1]<wid>[0][<sat>] rd, ms1, shift; Read + Clear (o-32b)
        mask:  32'b1000000_00000_00000_111_00000_1111111,   
        rs_valid_mask: 3'b000, 
        resp : '{
            accept : 1'b1,
            writeback : 1'b1,
            dualwrite : 1'b0,
            dualread : '0,
            loadstore : 1'b0,
            ecswrite : 1'b0,
            exc : 1'b0
        }
    }
};
endpackage
