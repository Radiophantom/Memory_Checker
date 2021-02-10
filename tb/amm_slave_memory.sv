'include "./bathtube_distribution.sv"

import settings_pkg::*;

class amm_slave_memory();

bit [7 : 0] memory_array [*];
bit [7 : 0] rd_data [$];

bathtube_distribution   bath_dist_obj;
err_trans_t             err_struct;

int cur_transaction_num = 0;
int err_transaction_num = 0;

int insert_err_enable   = 0;

local function automatic void wr_mem(
  input int unsigned          wr_addr,
  ref   bit           [7 : 0] wr_data [$]
);
  while( wr_data.size() )
    begin
      memory_array[wr_addr] = wr_data.pop_front();
      wr_addr++;
    end
endfunction

local task automatic rd_mem(
  input int unsigned          rd_addr,
  input int                   bytes_amount,
  ref   bit           [7 : 0] rd_data [$]
);
  repeat( $urandom_range( MIN_DELAY_PARAM - 1, MAX_DELAY_PARAM - 1 ) )
    @( posedge amm_if_v.clk );
  while( bytes_amount )
    begin
      if( memory_array.exists( rd_addr ) )
        rd_data.push_back( memory_array[rd_addr] );
      else
        rd_data.push_back( 8'd0 );
      bytes_amount--;
    end
endtask

virtual amm_if #(
  .ADDR_W   ( ADDR_W  ),
  .DATA_W   ( DATA_W  ),
  .BURST_W  ( BURST_W )
) amm_if_v;

function new(
  virtual amm_if #(
    .ADDR_W   ( ADDR_W  ),
    .DATA_W   ( DATA_W  ),
    .BURST_W  ( BURST_W )
  ) amm_if_v,
  mailbox err_trans_req_mbx,
  mailbox err_trans_ans_mbx
);
  this.amm_if_v           = amm_if_v;
  this.err_trans_req_mbx  = err_trans_req_mbx;
  this.err_trans_ans_mbx  = err_trans_ans_mbx;
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

local function automatic void scan_err_transaction();
  err_trans_req_mbx.get( err_transaction_num );
  cur_transaction_num = 0;
  insert_err_enable   = 1;
endfunction

local function automatic void corrupt_data(
  ref bit [7 : 0] wr_data [$]
);
  bath_dist_obj.set_dist_parameters( wr_data.size() );
  // get random number from 1 to queue size
  err_struct.addr           = bath_dist_obj.get_value(); 
  err_struct.data           = wr_data[err_struct.addr];
  wr_data[err_struct.addr]  = ( !wr_data[err_struct.addr] );
  // address not equal index in the queue
  err_struct.addr--; 
endfunction

local function automatic int start_offset(
  ref bit [DATA_B_W - 1 : 0] byteenable
);
  for( int i = 0; i < DATA_B_W; i++ )
    if( byteenable[i] )
      return i;
endfunction

local task automatic send_data(
  ref bit [7 : 0] rd_data [$]
);
  while( rd_data.size() )
    begin
      for( int i = 0; i < DATA_B_W; i++ )
        amm_if_v.readdata[7 + 8*i -: 8] <= rd_data.pop_front();
      if( RND_RVALID )
        begin
          amm_if_v.readdatavalid <= $urandom_range( 1 );
          while( !amm_if_v.readdatavalid )
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

local task automatic wr_data();

  int unsigned          wr_addr;
  bit           [7 : 0] wr_data [$];
  int                   bytes_amount;

  cur_transaction_num++;
  if( ADDR_TYPE == "BYTE" )
    begin
      wr_addr       = amm_if_v.address + start_offset( amm_if_v.byteenable );
      bytes_amount  = amm_if_v.burstcount;
    end
  else
    if( ADDR_TYPE == "WORD" )
      begin
        wr_addr       = amm_if_v.address * DATA_B_W;
        bytes_amount  = amm_if_v.burstcount * DATA_B_W;
      end
  while( 1 )
    begin
      wait( amm_if_v.write );
      for( int i = 0; i < DATA_B_W; i++ )
        if( amm_if_v.byteenable[i] && bytes_amount > 0 )
          begin
            wr_data.push_back( amm_if_v.writedata[7 + 8*i -: 8] );
            bytes_amount--;
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
      if( bytes_amount )
        @( posedge amm_if_v.clk );
      else
        break;
    end
  if( insert_err_enable )
    if( cur_transaction_num == err_transaction_num )
      begin
        corrupt_data( wr_data );
        err_struct.addr += wr_addr;
        err_trans_ans_mbx.put( err_struct );
        insert_err_enable = 0;
      end
  wr_mem( wr_addr, wr_data );
endtask

local task automatic rd_data();

  int unsigned  rd_addr;
  int           bytes_amount;

  if( ADDR_TYPE == "BYTE" )
    rd_addr  = amm_if_v.address;
  else
    rd_addr  = amm_if_v.address * DATA_B_W;
  bytes_amount = amm_if_v.burstcount * DATA_B_W;
  if( RND_WAITREQ )
    begin
      amm_if_v.waitrequest <= $urandom_range( 1 );
      while( amm_if_v.waitrequest )
        begin
          @( posedge amm_if_v.clk );
          amm_if_v.waitrequest <= $urandom_range( 1 );
        end
    end
  rd_mem( rd_addr, bytes_amount );
endtask

local task automatic run();

  bath_dist_obj = new();

  forever
    fork
      begin : scan_error_mailbox_channel
        scan_err_transaction();
      end
      begin : rd_data_channel
        wait( rd_data.size() > 0 );
        send_data( rd_data );
      end
      begin : wr_rd_request_channel
        @( posedge amm_if_v.clk );
        if( amm_if_v.write )
          wr_data();
        else
          if( amm_if_v.read )
            rd_data();
      end
    join_none

endtask

endclass
