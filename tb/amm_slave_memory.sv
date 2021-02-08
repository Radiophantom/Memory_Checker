class amm_slave_memory(
  parameter int ADDR_W  = 31
 );

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

bit [7 : 0] memory_array [*];

function new(
  mailbox wr_req_mbx,
  mailbox rd_req_mbx,
  mailbox rd_data_mbx
);

  this.wr_req_mbx   = wr_req_mbx;
  this.rd_req_mbx   = rd_req_mbx;
  this.rd_data_mbx  = rd_data_mbx;

endfunction

//local function automatic void init_interface();

//  amm_if_v.read           = 1'b0;
//  amm_if_v.write          = 1'b0;
//  amm_if_v.address        = '0;
//  amm_if_v.writedata      = '0;
//  amm_if_v.byteenable     = '0;
//  amm_if_v.burstcount     = '0;
//  amm_if_v.readdatavalid  = 1'b0;
//  amm_if_v.readdata       = '0;
//  amm_if_v.waitrequest    = 1'b0;
//  
//  fork
//    run();
//  join_none

//endfunction

local task automatic wr_data();

  
  wr_trans_t  wr_req_struct;
  int         units_amount;

  wr_req_mbx.put( wr_req_struct );

endtask

local task automatic rd_data();

  rd_trans_t  rd_req_struct;
  rd_data_t   rd_data;

  send_data( rd_data );

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
