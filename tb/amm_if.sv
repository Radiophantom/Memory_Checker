interface amm_if#(
  parameter int ADDR_W = 4,
  parameter int DATA_W = 31,
)(
  input clk_i
);

logic                   read;
logic                   write;
logic [ADDR_W - 1 : 0]  address;
logic [DATA_W - 1 : 0]  writedata;
logic [DATA_W - 1 : 0]  readdata;

modport master(
  output read,
  output write,
  output address,
  output writedata,
  input  readdata
);

modport slave(
  input  read,
  input  write,
  input  address,
  input  writedata,
  output readdata
);

endinterface
