'include "./transaction.sv"
'include "./bathtube_distribution.sv"

import settings_pkg::*;

class amm_slave();

bit [7 : 0] memory_array [*];
bit [7 : 0] rd_data [$];

local task automatic wr_mem(
  input bit [ADDR_W - 1 : 0]  wr_addr,
  ref   bit [7 : 0]           wr_data [$]
);

  while( wr_data.size() )
    begin
      memory_array[wr_addr] = wr_data.pop_front();
      wr_addr++;
    end

endtask

local task automatic rd_mem(
  input bit [ADDR_W - 1 : 0]  rd_addr,
  input int                   bytes_amount
);

  while( bytes_amount )
    begin
      if( memory_array.exists( rd_addr ) )
        rd_data.push_back( memory_array[rd_start_addr] );
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
  mailbox err_transaction_mbx,
  mailbox err_transaction_struct_mbx
);

  this.amm_if_v                   = amm_if_v;
  this.err_transaction_mbx        = err_transaction_mbx;
  this.err_transaction_struct_mbx = err_transaction_struct_mbx;

  init_interface();

endfunction

transaction       wr_req_obj;
transaction_cbs   wr_req_obj_err;

int write_transaction_num = 0;
int err_transaction_num   = 0;

semaphore err_insert_sema = new();

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

task automatic set_err_transaction_num();
  fork
    forever
      begin
        err_transaction_mbx.get( err_transaction_num );
        write_transaction_num = 0;
        err_insert_sema.put();
      end
  join_none
endtask

local task automatic wr_data();

  int units_amount;

  wr_req_obj = new();

  if( ADDR_TYPE == "BYTE" )
    begin
      wr_req_obj.put_addr( amm_if_v.address );
      units_amount = amm_if_v.burstcount;
    end
  else
    begin
      wr_req_obj.put_addr( amm_if_v.address << ADDR_B_W );
      units_amount = amm_if_v.burstcount * DATA_B_W;
    end

  while( 1 )
    begin
      wait( amm_if_v.write );
      for( int i = 0; i < DATA_B_W; i++ )
        if( amm_if_v.byteenable[i] )
          begin
            wr_req_obj.put_data( amm_if_v.writedata[7 + 8*i -: 8] );
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

  if( write_transaction_num == err_transaction_num )
    if( err_insert_sema.try_get() )
      begin
        wr_req_obj_err = new();
        wr_req_obj_err = wr_req_obj;
        wr_req_obj.corrupt_data();
        err_transaction_struct_mbx.put( wr_req_obj.corrupt_addr, wr_req_obj.orig_data, wr_req_obj.corrupt_data );
      end

  wr_req_mbx.put( wr_req_obj );

endtask

rd_trans_t  rd_req_struct;
rd_data_t   rd_data;

local task automatic rd_data();

  if( ADDR_TYPE == "BYTE" )
    rd_req_struct.rd_start_addr = amm_if_v.address;
  else
    rd_req_struct.rd_start_addr = ( amm_if_v.address << ADDR_B_W );
  rd_req_struct.words_amount = amm_if_v.burstcount * DATA_B_W;

  amm_if_v.waitrequest <= 1'b1;

  rd_mem( rd_req_struct.rd_start_addr, rd_req_struct.words_amount );
  send_data( rd_data );

  amm_if_v.waitrequest <= 1'b0;

endtask


local task automatic send_data(
  ref bit [7 : 0] rd_data [$]
);

  repeat( $urandom_range( MIN_DELAY_PARAM, MAX_DELAY_PARAM ) );
    @( posedge amm_if_v.clk );

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

bit [ADDR_W - 1 : 0]    corrupt_addr;
bathtube_distribution   corrupt_index;

function automatic void corrupt_data(
  ref [7 : 0] wr_data [$]
);

  corrupt_index = new();

  corrupt_index.set_dist_parameters( wr_data.size() );
  corrupt_index.randomize();
  wr_data[corrupt_index.value] = !wr_data[corrupt_index.value];

  corrupt_addr = wr_addr + corrupt_index - 1;

endfunction

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
