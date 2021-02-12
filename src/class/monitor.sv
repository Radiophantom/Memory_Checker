class monitor;

statistic stat_var;

mailbox mon2scoreb_mbx;

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
  mailbox mon2scoreb_mbx
);
  this.amm_if_v       = amm_if_v;
  this.mon2scoreb_mbx = mon2scoreb_mbx;
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
endfunction

task automatic run();
  rd_bytes_count();
  wr_bytes_count();
  wr_ticks_count();
  rd_req_count();
endtask : run

local task automatic rd_bytes_count;
  fork
    while( !end_test_event.triggered )
      begin
        @( posedge amm_if_v.clk );
        if( amm_if_v.readdatavalid )
          rd_bytes  +=  DATA_B_W;
      end
  join_none
endtask : rd_bytes_count

task automatic run();
  stat_var = new();

