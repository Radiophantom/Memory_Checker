`include "../interface/amm_if.sv"

import settings_pkg::*;

class driver;

virtual amm_if #(
  .ADDR_W   ( 4   ),
  .DATA_W   ( 32  )
) amm_if_v;

mailbox       agent2driv;
mailbox       driv2scoreb;

res_struct_t    res_struct;
test_struct_t   test_struct;

bit [31 : 0]  rd_data;

function new(
  virtual amm_if #(
    .ADDR_W   ( 4   ),
    .DATA_W   ( 32  )
  ) amm_if_v,
  mailbox agent2driv,
  mailbox driv2scoreb
);
  this.amm_if_v     = amm_if_v;
  this.agent2driv   = agent2driv;
  this.driv2scoreb  = driv2scoreb;
  init_interface();
endfunction

local function automatic void init_interface();
  amm_if_v.read       = 1'b0;
  amm_if_v.write      = 1'b0;
  amm_if_v.address    = '0;
  amm_if_v.writedata  = '0;
  amm_if_v.readdata   = '0;
endfunction

function automatic start_test();
  wr_word( 1, test_struct.csr_1_reg );
  wr_word( 2, test_struct.csr_2_reg );
  wr_word( 3, test_struct.csr_3_reg );
  wr_word( 0, 32'd1                 );
endfunction

local task automatic wr_word(
  input int           wr_addr,
  input bit [31 : 0]  wr_data
);
  amm_if_v.address    <= wr_addr;
  amm_if_v.writedata  <= wr_data;
  amm_if_v.write      <= 1'b1;
  @( posedge amm_if_v.clk );
  amm_if_v.write      <= 1'b0;
endtask : wr_word

local task automatic poll_finish_bit();
  do
    rd_word( 4 );
  while( rd_data == 0 );
endtask : poll_finish_bit

local task automatic rd_word(
  input int rd_addr
);
  amm_if_v.address  <= rd_addr;
  amm_if_v.read     <= 1'b1;
  @( posedge amm_if_v.clk );
  amm_if_v.read     <= 1'b0;
  @( posedge amm_if_v.clk );
  rd_data = amm_if_v.readdata;
endtask : rd_word

local task automatic save_test_result();
  rd_word( 5 );
  res_struct.result_reg   = rd_data;
  rd_word( 6 );
  res_struct.err_addr_reg = rd_data;
  rd_word( 7 );
  res_struct.err_data_reg = rd_data;
  rd_word( 8 );
  res_struct.wr_ticks_reg = rd_data;
  rd_word( 9 );
  res_struct.wr_units_reg = rd_data;
  rd_word( 10 );
  res_struct.rd_ticks_reg = rd_data;
  rd_word( 11 );
  res_struct.rd_words_reg = rd_data;
  rd_word( 12 );
  res_struct.min_max_reg  = rd_data;
  rd_word( 13 );
  res_struct.sum_reg      = rd_data;
  rd_word( 14 );
  res_struct.rd_req_reg   = rd_data;
endtask : save_test_result

task automatic run();
  fork
    forever
      begin
        agent2driv.get( test_struct );
        start_test();
        poll_finish_bit();
        save_test_result();
        driv2scoreb.put( res_struct );
      end
  join_none
endtask ; run

endclass : driver
