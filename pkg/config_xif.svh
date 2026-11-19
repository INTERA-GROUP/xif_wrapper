`ifndef XIF_ID_WIDTH_CFG
    `define XIF_ID_WIDTH_CFG 4
`endif

`ifndef XIF_X_RFR_WIDTH
    `define XIF_X_RFR_WIDTH  32  //Port for src read. Modify if double read: 64
`endif

`ifndef XIF_DUAL_REG_READ_CFG
    `define XIF_DUAL_REG_READ_CFG  0 //enable for dual enable and disable
`endif

// Additional CV-X-IF v1.0 settings - Maryana Pyzh <maryana.pyzh@irvmic.com>
`ifndef XIF_NUM_RS_CFG
    `define XIF_NUM_RS_CFG 3
`endif

`ifndef XIF_X_RFW_WIDTH
    `define XIF_X_RFW_WIDTH 32
`endif

`ifndef XIF_NUM_HARTS_CFG
    `define XIF_NUM_HARTS_CFG 1
`endif

`ifndef XIF_HARTID_WIDTH_CFG
    `define XIF_HARTID_WIDTH_CFG 32
`endif

`ifndef XIF_ISSUE_REGISTER_SPLIT_CFG
    `define XIF_ISSUE_REGISTER_SPLIT_CFG 0
`endif

`ifndef XIF_DUAL_REG_WRITE_CFG
    `define XIF_DUAL_REG_WRITE_CFG 0
`endif
