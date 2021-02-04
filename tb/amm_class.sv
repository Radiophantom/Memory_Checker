class amm_class (
  parameter int ADDR_W = 4,
  parameter int DATA_W = 31,
 );

virtual amm_if #(
  .ADDR_W ( ADDR_W ),
  .DATA_W ( DATA_W )
) amm_if_v;

mailbox wr_data_mbx;
mailbox rd_data_mbx;

function new(
  virtual amm_if #(
    .ADDR_W ( ADDR_W ),
    .DATA_W ( DATA_W )
  ) amm_if_v,
  mailbox wr_data_mbx,
  mailbox rd_data_mbx
);

  this.amm_if_v = amm_if_v;
  this.wr_data_mbx = wr_data_mbx;
  this.rd_data_mbx = rd_data_mbx;
  init_interface();

endfunction

local function automatic void init_interface();

  amm_if_v.write      = 1'b0;
  amm_if_v.read       = 1'b0;
  amm_if_v.address    = '0;
  amm_if_v.writedata  = '0;
  amm_if_v.readdata   = '0;
  
  fork
    run();
  join_none

endfunction

task automatic wr_word(
  input bit [ADDR_W - 1 : 0] address,
  ref   bit [DATA_W - 1 : 0] data
);

  amm_if_v.address    <= address;
  amm_if_v.writedata  <= data;
  amm_if_v.write      <= 1'b1;
  @( posedge amm_if_v.clk );
  amm_if_v.write      <= 1'b0;

endtask

task automatic rd_word(
  input bit [ADDR_W - 1 : 0] address
);

  bit [DATA_W - 1 : 0] readdata;

  fork
    begin : read_req_channel
      amm_if_v.address  <= address;
      amm_if_v.read     <= 1'b1;
      @( posedge amm_if_v.clk );
      amm_if_v.read     <= 1'b0;
    end
    begin : read_data_channel
      if( amm_if_v.read )
        begin
          @( posedge amm_if_v.clk );
          readdata = amm_if_v.readdata;
        end
    end
  join
  rd_data_mbx.put( data );

endtask
