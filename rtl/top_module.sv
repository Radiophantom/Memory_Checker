import settings_pkg::*;

module top_module(
  input                                 rst_i,
  input                                 clk_sys_i,
  input                                 clk_ctrl_i,

  // Avalon-MM input interface

  input                                 sys_read_i,
  input                                 sys_write_i,
  input         [3  : 0]                sys_address_i,
  input         [31 : 0]                sys_writedata_i,

  output  logic [31 : 0]                sys_readdata_o,
  
  // Avalon-MM output interface
  input                                 ctrl_readdatavalid_i,
  input         [AMM_DATA_W - 1    : 0] ctrl_readdata_i,

  input                                 ctrl_waitrequest_i,

  output logic  [AMM_ADDR_W - 1    : 0] ctrl_address_o,
  output logic                          ctrl_read_o,
  output logic                          ctrl_write_o,
  output logic  [AMM_DATA_W - 1    : 0] ctrl_writedata_o,
  output logic  [AMM_BURST_W - 1   : 0] ctrl_burstcount_o,
  output logic  [BYTE_PER_WORD - 1 : 0] ctrl_byteenable_o
);





endmodule
