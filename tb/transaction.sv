'include "./bathtube_distribution.sv"

import settings_pkg::*;

class transaction();

bit [ADDR_W - 1 : 0]  wr_addr;
bit [7 : 0]           wr_data [$];

virtual function automatic void corrupt_data();
endfunction

function automatic void put_addr( input bit [ADDR_W - 1 : 0] wr_addr );
  this.wr_addr = wr_addr;
endfunction

function automatic void put_data( input bit [7 : 0] wr_byte );
  wr_data.push_back( wr_byte );
endfunction : put_data

endclass : transaction

class transaction_cbs extends transaction;

bit [ADDR_W - 1 : 0]    corrupt_addr;
bathtube_distribution   corrupt_index;

virtual function automatic void corrupt_data();

  set_dist_parameters( wr_data.size() );
  corrupt_index.randomize();
  wr_data[corrupt_index] = !wr_data[corrupt_index];
  corrupt_addr = wr_addr + corrupt_index - 1;

endfunction

endclass transaction_cbs
