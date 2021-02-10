import settings_pkg::*;

class amm_master_lite();

virtual amm_if #(
  .ADDR_W   ( ADDR_W  ),
  .DATA_W   ( DATA_W  )
) amm_if_v;

random_scenario rnd_scen_obj;

mailbox wr_req_mbx;
mailbox rd_ans_mbx;

function new(
  virtual amm_if #(
    .ADDR_W   ( 4   ),
    .DATA_W   ( 32  )
  ) amm_if_v,
  mailbox wr_req_mbx,
  mailbox rd_ans_mbx
);
  this.amm_if_v   = amm_if_v;
  this.wr_req_mbx = wr_req_mbx;
  this.rd_ans_mbx = rd_ans_mbx;
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

function automatic start_test();
  wr_word( 1, rnd_scen_obj.test_parameters[0] );
  if( rnd_scen_obj.addr_mode == 0 || rnd_scen_obj.addr_mode == 4 )
    wr_word( 2, rnd_scen_obj.test_parameters[1] );
  if( rnd_scen_obj.data_mode == 0 )
    wr_word( 3, rnd_scen_obj.test_parameters[2] );
  wr_word( 0, 32'd1 );
endfunction

local task automatic wr_word(
  input bit [3 : 0]   wr_addr,
  input bit [31 : 0]  wr_data
);
  amm_if_v.address    <= wr_addr;
  amm_if_v.writedata  <= wr_data;
  amm_if_v.write      <= 1'b1;
  @( posedge amm_if_v.clk );
  amm_if_v.write      <= 1'b0;
endtask

bit [31 : 0] rd_data;

local task automatic poll_finish_bit();
  do
    rd_word( 5 );
  while( rd_data == 0 );
endtask

local task automatic rd_word(
  input bit [3 : 0]   rd_addr
);
  amm_if_v.address  <= rd_addr;
  amm_if_v.read     <= 1'b1;
  @( posedge amm_if_v.clk );
  amm_if_v.read     <= 1'b0;
  @( posedge amm_if_v.clk );
  rd_data = amm_if_v.readdata;
endtask

typedef struct packed{
  bit [31 : 0] res_reg,
  bit [31 : 0] err_addr_reg,
  bit [31 : 0] err_data_reg,
  bit [31 : 0] wr_ticks_reg,
  bit [31 : 0] wr_units_reg,
  bit [31 : 0] rd_ticks_reg,
  bit [31 : 0] rd_words_reg,
  bit [31 : 0] min_max_dly_reg,
  bit [31 : 0] sum_dly_reg,
  bit [31 : 0] rd_req_cnt_reg
} test_res_t;

test_res_t res_struct;

local task automatic save_test_result();
  bit [31 : 0] rd_data;
  rd_word( 5 );
  res_struct.res_reg = rd_data;
  if( rd_data )
    begin
      rd_word( 6 );
      res_struct.err_addr_reg = rd_data;
      rd_word( 7 );
      res_struct.err_data_reg = rd_data;
    end
  rd_word( 8 );
  res_struct.wr_ticks_reg = rd_data;
  rd_word( 9 );
  res_struct.wr_units_reg = rd_data;
  rd_word( 10 );
  res_struct.rd_ticks_reg = rd_data;
  rd_word( 11 );
  res_struct.rd_words_reg = rd_data;
  rd_word( 12 );
  res_struct.min_max_dly_reg = rd_data;
  rd_word( 13 );
  res_struct.sum_dly_reg = rd_data;
  rd_word( 14 );
  res_struct.rd_req_cnt_reg = rd_data;
endtask

task automatic run();

  forever
    begin : wr_channel
      wr_req_mbx.get( rnd_scen_obj );
      start_test();
      poll_finish_bit();
      save_test_result();
      rd_ans_mbx.put( res_struct );
    end

endtask

endclass amm_master_lite
