class amm_master_lite(
  parameter int ADDR_W  = 4,
  parameter int DATA_W  = 31
 );

virtual amm_if #(
  .ADDR_W   ( ADDR_W  ),
  .DATA_W   ( DATA_W  )
) amm_if_v;

typedef struct{
  bit [ADDR_W - 1 : 0]  wr_addr;
  bit [DATA_W - 1 : 0]  wr_data;
} wr_trans_t;

typedef bit [ADDR_W - 1 : 0] rd_trans_t;

typedef bit [DATA_W - 1 : 0] rddata_t;

mailbox wr_req_mbx = new();
mailbox rd_req_mbx = new();

mailbox rd_data_mbx;

function new(
  virtual amm_if #(
    .ADDR_W   ( ADDR_W  ),
    .DATA_W   ( DATA_W  )
  ) amm_if_v,
  mailbox rd_data_mbx
);

  this.amm_if_v       = amm_if_v;
  this.rd_data_mbx    = rd_data_mbx;

  init_interface();

endfunction

local function automatic void init_interface();

  amm_if_v.read       = 1'b0;
  amm_if_v.write      = 1'b0;
  amm_if_v.address    = '0;
  amm_if_v.writedata  = '0;
  amm_if_v.readdata   = '0;
  
  fork
    run();
  join_none

endfunction

task automatic wr_word(
  ref bit [ADDR_W - 1 : 0]  wr_addr,
  ref bit [DATA_W - 1 : 0]  wr_data
);

  wr_trans_t wr_req_struct;

  wr_req_struct.wr_addr = wr_addr;
  wr_req_struct.wr_data = wr_data;

  wr_req_mbx.put( wr_req_struct );

endtask

task automatic rd_word(
  ref bit [ADDR_W - 1 : 0]  rd_addr
);

  rd_trans_t rd_req_struct;

  rd_req_struct.rd_addr = rd_addr;

  rd_req_mbx.put( rd_req_struct );

endtask

local task automatic wr_data(
  ref bit [ADDR_W - 1 : 0]  wr_addr,
  ref bit [DATA_W - 1 : 0]  wr_data
);

  amm_if_v.address    <= wr_addr;
  amm_if_v.write      <= 1'b1;
  amm_if_v.writedata  <= wr_data;
  @( posedge amm_if_v.clk );
  amm_if_v.write      <= 1'b0;

endtask

local task automatic rd_data(
  ref bit [ADDR_W - 1 : 0] rd_addr
);

  rddata_t  rd_data;

  amm_if_v.address  <= rd_addr;
  amm_if_v.read     <= 1'b1;
  @( posedge amm_if_v.clk );
  amm_if_v.read     <= 1'b0;
  @( posedge amm_if_v.clk );
  rd_data            = amm_if_v.readdata;

  rd_data_mbx.put( rd_data );

endtask

wr_trans_t wr_req;
rd_trans_t rd_req;

task automatic run();

  forever
    fork
      begin : wr_channel
        wr_req_mbx.get( wr_req );
        wr_data(  .wr_addr( wr_req.wr_addr ),
                  .wr_data( wr_req.wr_data ) );
      end
      begin : rd_channel
        rd_req_mbx.get( rd_req );
        rd_data( .rd_addr( rd_req.rd_addr ) );
      end
    join_none

endtask

endclass amm_master_lite
