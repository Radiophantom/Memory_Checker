`include "./transaction.vs"
`include "./random_scenario.sv"
`include "./amm_slave_memory.sv"
`include "./amm_master_lite.sv"
`include "../rtl/mem_checker.sv"

import settings_pkg::*;

`timescale 1 ps / 1 ps

module mem_checker_tb();

generator gen_class;

mailbox wr_req_mbx = new();
mailbox err_trans_ans_mbx = new();

bit rst_i;
bit clk_sys_i;
bit clk_mem_i;

amm_if.master_lite #(
  .ADDR_W(  4   ),
  .DATA_W(  32  )
) amm_master_if (
  .clk( clk_sys_i )
);

amm_if.slave #(
  .ADDR_W(  ADDR_W ),
  .DATA_W(  DATA_W ),
  .BURST_W( BURST_W )
) amm_slave_if (
  .clk( clk_mem_i )
);

task automatic clk_gen();
  clk_sys_i = 0;
  clk_mem_i = 0;
  forever
    fork
      begin
        #( CLK_SYS_T / 2 );
        clk_sys_i = !clk_sys_i;
      end
      begin
        #( CLK_MEM_T / 2 );
        clk_mem_i = !clk_mem_i;
      end
    join_none
endtask

task automatic rst_apply();
  rst_i = 0;
  @( posedge clk_sys_i );
  rst_i = 1;
endtask


initial
  begin


endmodule
