class amm_slave(
  parameter int     ADDR_W      = 4,
  parameter int     DATA_W      = 31,
  parameter int     BURST_W     = 11,
  parameter string  ADDR_TYPE   = "BYTE", // BYTE or WORD
  parameter int     RND_WAITREQ = 0,
  parameter int     RND_RVALID  = 0
 );

localparam int DATA_B_W = DATA_W / 8;
localparam int ADDR_B_W = $clog2( DATA_B_W );

virtual amm_if #(
  .ADDR_W   ( ADDR_W  ),
  .DATA_W   ( DATA_W  ),
  .BURST_W  ( BURST_W )
) amm_if_v;

typedef struct{
  bit [ADDR_W - 1 : 0]  wr_start_addr;
  bit [7 : 0]           wr_data [$];
} wr_trans_t;

typedef struct{
  bit [ADDR_W - 1 : 0]  rd_start_addr;
  int                   words_amount ;
} rd_trans_t;

typedef bit [7 : 0] rd_data_t [$];

mailbox wr_req_mbx;
mailbox rd_req_mbx;

mailbox rd_data_mbx;

function new(
  virtual amm_if #(
    .ADDR_W   ( ADDR_W  ),
    .DATA_W   ( DATA_W  ),
    .BURST_W  ( BURST_W )
  ) amm_if_v,
  mailbox wr_req_mbx,
  mailbox rd_req_mbx,
  mailbox rd_data_mbx
);

  this.amm_if_v     = amm_if_v;
  this.wr_req_mbx   = wr_req_mbx;
  this.rd_req_mbx   = rd_req_mbx;
  this.rd_data_mbx  = rd_data_mbx;

  init_interface();

endfunction

local function automatic void init_interface();

  amm_if_v.read           = 1'b0;
  amm_if_v.write          = 1'b0;
  amm_if_v.address        = '0;
  amm_if_v.writedata      = '0;
  amm_if_v.byteenable     = '0;
  amm_if_v.burstcount     = '0;
  amm_if_v.readdatavalid  = 1'b0;
  amm_if_v.readdata       = '0;
  amm_if_v.waitrequest    = 1'b0;
  
  fork
    run();
  join_none

endfunction

local task automatic wr_data();

  wr_trans_t  wr_req_struct;
  int         units_amount;

  if( ADDR_TYPE == "BYTE" )
    begin
      wr_req_struct.wr_start_addr = amm_if_v.address;
      units_amount                = amm_if_v.burstcount;
    end
  else
    begin
      wr_req_struct.wr_start_addr = ( amm_if_v.address << ADDR_B_W );
      units_amount                = amm_if_v.burstcount * DATA_B_W;
    end

  while( 1 )
    begin
      wait( amm_if_v.write );
      for( int i = 0; i < DATA_B_W; i++ )
        if( amm_if_v.byteenable[i] )
          begin
            wr_req_struct.wr_data.push_back( amm_if_v.writedata[7 + 8*i -: 8] );
            units_amount--;
          end
      if( RND_WAITREQ )
        begin
          amm_if_v.waitrequest <= $urandom_range( 1 );
          while( amm_if_v.waitrequest )
            begin
              @( posedge amm_if_v.clk );
              amm_if_v.waitrequest <= $urandom_range( 1 );
            end
        end
      else
        amm_if_v.waitrequest <= 1'b0;
      if( units_amount > 0 )
        @( posedge amm_if_v.clk );
      else
        break;
    end

  wr_req_mbx.put( wr_req_struct );

endtask

local task automatic rd_data();

  rd_trans_t  rd_req_struct;
  rd_data_t   rd_data;

  if( ADDR_TYPE == "BYTE" )
    rd_req_struct.rd_start_addr = amm_if_v.address;
  else
    rd_req_struct.rd_start_addr = ( amm_if_v.address << ADDR_B_W );
  rd_req_struct.words_amount = amm_if_v.burstcount * DATA_B_W;

  amm_if_v.waitrequest <= 1'b1;

  rd_req_mbx.put( rd_req_struct );
  rd_data_mbx.get( rd_data );
  send_data( rd_data );

  amm_if_v.waitrequest <= 1'b0;

endtask

local task automatic send_data( ref rd_data_t rd_data );

  while( rd_data.size() )
    begin
      for( int i = 0; i < DATA_B_W; i++ )
        amm_if_v.readdata[7 + 8*i -: 8] <= rd_data.pop_front();
      if( RND_RVALID )
        begin
          amm_if_v.readdatavalid <= $urandom_range( 1 );
          while( ~amm_if_v.readdatavalid )
            begin
              @( posedge amm_if_v.clk );
              amm_if_v.readdatavalid <= $urandom_range( 1 );
            end
        end
      else
        amm_if_v.readdatavalid <= 1'b1;
      @( posedge amm_if_v.clk );
    end
  amm_if_v.readdatavalid <= 1'b0;

endtask

task automatic run();

  forever
    begin
      @( posedge amm_if_v.clk );
      if( amm_if_v.write )
        wr_data();
      else
        if( amm_if_v.read )
          rd_data();
    end

endtask

endclass
