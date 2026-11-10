// CV-X-IF v1.0 adaptation: Maryana Pyzh <maryana.pyzh@irvmic.com> INNOVA IRV Microelectronics, S.L.
// Description: CV-X-IF v1.0 package.

`include "config_xif.svh"

package cvxif_v1_pkg;

  parameter int unsigned X_NUM_RS            = 3;
  parameter int unsigned X_ID_WIDTH          = `XIF_ID_WIDTH_CFG;
  parameter int unsigned X_RFR_WIDTH         = 32;
  parameter int unsigned X_RFW_WIDTH         = 32;
  parameter int unsigned X_NUM_HARTS         = 1;
  parameter int unsigned X_HARTID_WIDTH      = 32;
  parameter int unsigned X_DUALREAD          = 0;  // must match XIF_DUAL_REG_READ_CFG in config_xif.svh
  parameter int unsigned X_ISSUE_REGISTER_SPLIT = 0;

  typedef logic [X_ID_WIDTH-1:0] id_t;
  typedef logic [X_HARTID_WIDTH-1:0] hartid_t;
  typedef logic [X_NUM_RS+X_DUALREAD-1:0] readregflags_t;

  typedef struct packed {
    logic [31:0] instr;
    hartid_t     hartid;
    id_t         id;
  } x_issue_req_t;

  typedef struct packed {
    logic          accept;
    logic          writeback;
    readregflags_t register_read;  // one bit per register source; width = X_NUM_RS + X_DUALREAD
  } x_issue_resp_t;

  typedef struct packed {
    hartid_t                         hartid;
    id_t                             id;
    logic [X_NUM_RS-1:0][X_RFR_WIDTH-1:0] rs;
    readregflags_t                   rs_valid;
  } x_register_t;

  typedef struct packed {
    hartid_t hartid;
    id_t     id;
    logic    commit_kill;
  } x_commit_t;

  typedef struct packed {
    hartid_t                hartid;
    id_t                    id;
    logic [X_RFW_WIDTH-1:0] data;
    logic [4:0]             rd;
    logic                   we;
  } x_result_t;

endpackage
