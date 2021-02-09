import settings_pkg::*;

class amm_slave_memory();

transaction wr_req_obj;

mailbox wr_req_mbx;
mailbox rd_req_mbx;

mailbox rd_data_mbx;

bit [7 : 0] memory_array [*];

bit [7 : 0] rd_data_t [$];

function new(
  mailbox wr_req_mbx,
  mailbox rd_req_mbx,
  mailbox rd_data_mbx
);

  this.wr_req_mbx   = wr_req_mbx;
  this.rd_req_mbx   = rd_req_mbx;
  this.rd_data_mbx  = rd_data_mbx;

endfunction

local task automatic wr_data();

  int wr_addr;
  wr_req_obj = new();

  wr_req_mbx.get( wr_req_obj );
  wr_addr = wr_req_obj.wr_addr;

  while( wr_req_obj.wr_data.size() )
    begin
      memory_array[wr_addr] = wr_req_obj.wr_data.pop_front();
      wr_addr++;
    end
  //wr_req_obj = null; Не должно повлиять вообще ни на что по идее, надо прове
  //рить

endtask

local task automatic rd_data();

  rd_trans_t  rd_req_struct;
  rd_data_t   rd_data;

  int words_amount;
  int rd_start_addr;
  
  rd_req_mbx.get( rd_req_struct );

  words_amount  = rd_req_struct.words_amount;
  rd_start_addr = rd_req_struct.rd_start_addr;

  while( words_amount )
    begin
      if( memory_array.exists( rd_start_addr ) )
        rd_data.push_back( memory_array[rd_start_addr] );
      else
        rd_data.push_back( 8'd0 );
      words_amount--;
    end

endtask

task automatic run();

  forever
    begin
      if( wr_req_mbx.num )
        wr_data();
      else
        if( rd_req_mbx.num )
          rd_data();
    end

endtask

endclass
