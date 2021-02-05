class amm_class (
  parameter int ADDR_W    = 4,
  parameter int DATA_W    = 31,
  parameter int BURST_W   = 11
  parameter string ADDR_TYPE = BYTE // BYTE or WORD
 );

localparam int DATA_B_W = ( DATA_W / 8 );
localparam int ADDR_B_W = $clog2( DATA_B_W );

virtual amm_if #(
  .ADDR_W   ( ADDR_W  ),
  .DATA_W   ( DATA_W  ),
  .BURST_W  ( BURST_W )
) amm_if_v;

semaphore trans_busy_sema;

mailbox   wr_data_mbx;
mailbox   rd_data_mbx;

function new(
  virtual amm_if #(
    .ADDR_W   ( ADDR_W  ),
    .DATA_W   ( DATA_W  ),
    .BURST_W  ( BURST_W )
  ) amm_if_v,
  mailbox transaction_req_mbx,
  mailbox wr_data_mbx,
  mailbox rd_data_mbx
);

  this.amm_if_v             = amm_if_v;
  this.transaction_req_mbx  = transaction_req_mbx;
  this.wr_data_mbx          = wr_data_mbx;
  this.rd_data_mbx          = rd_data_mbx;

  init_interface();

endfunction

local function automatic void init_interface();

  amm_if_v.address        = '0;
  amm_if_v.read           = 1'b0;
  amm_if_v.write          = 1'b0;
  amm_if_v.byteenable     = '0;
  amm_if_v.burstcount     = '0;
  amm_if_v.readdatavalid  = 1'b0;
  amm_if_v.writedata      = '0;
  amm_if_v.readdata       = '0;
  amm_if_v.waitrequest    = 1'b1;
  
  fork
    run();
  join_none

endfunction

task automatic wr_bytes(
  input bit [ADDR_W - 1 : 0]  wr_addr,
  ref   bit [7 : 0]           wr_data [$]
);

  trans_busy_sema.get();

  amm_if_v.address    <= { wr_addr[ADDR_W - 1 : ADDR_B_W], ADDR_B_W'( 0 ) };
  if( ADDR_TYPE == BYTE )
    amm_if_v.burstcount <= wr_data.size();
  else
    amm_if_v.burstcount <= wr_data.size() / DATA_W;
  while( wr_data.size() )
    begin
      for( int i = 0; i < DATA_B_W; i++ )
        if( wr_data.size() )
          begin
            amm_if_v.writedata[7 + 8*i : 8*i] <= wr_data.pop_front();
            amm_if_v.byteenable[i]            <= 1'b1;
          end
        else
          begin
            amm_if_v.writedata[7 + 8*i : 8*i] <= 8'd0;
            amm_if_v.byteenable[i]            <= 1'b0;
          end
      amm_if_v.write      <= 1'b1;
      @( posedge amm_if_v.clk );
      while( amm_if_v.waitrequest )
        @( posedge amm_if_v.clk );
    end
  amm_if_v.write <= 1'b0;

  trans_busy_sema.put();

endtask

task automatic wr_word(
  input bit [ADDR_W - 1 : 0] wr_addr,
  ref   bit [DATA_W - 1 : 0] wr_data [$]
);

  logic [DATA_W - 1 : 0]  data_word;
  logic [7 : 0]           data_bytes [$];

  while( wr_data.size() )
    begin
      data_word = wr_data.pop_front();
      for( int i = 0; i < ( DATA_W / 8 ); i++ )
        data_bytes.push_back( data_word[7 + 8*i : 8*i] );
    end

  wr_bytes( wr_addr, data_bytes );

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
  join_any
  rd_data_mbx.put( data );

endtask


task automatic run();

  trans_busy_sema = new( 1 );

endtask
