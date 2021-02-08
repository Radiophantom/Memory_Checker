interface amm_if#(
  parameter int ADDR_W  = 4,
  parameter int DATA_W  = 31,
  parameter int BURST_W = 11
)(
  input clk
);

logic [ADDR_W - 1 : 0]      address;
logic                       read;
logic                       write;
logic [DATA_W / 8 - 1 : 0]  byteenable;
logic [BURST_W - 1 : 0]     burstcount;
logic                       readdatavalid;
logic [DATA_W - 1 : 0]      writedata;
logic [DATA_W - 1 : 0]      readdata;
logic                       waitrequest;

modport master(
  output address,
  output read,
  output write,
  output byteenable,
  output burstcount,
  input  readdatavalid,
  output writedata,
  input  readdata,
  input  waitrequest
);

modport master_lite(
  output address,
  output read,
  output write,
  output writedata,
  input  readdata
);

modport slave(
  input  address,
  input  read,
  input  write,
  input  byteenable,
  input  burstcount,
  output readdatavalid,
  input  writedata,
  output readdata,
  output waitrequest
);

endinterface
