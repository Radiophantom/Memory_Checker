Module address_block #(
  parameter DATA_DDR_W = 64,
  parameter DATA_AMM_W = 512
  parameter ADDR_TYPE = BYTE
)( 
  input clk_i, 
  input rst_i,

  input start_transaction_en,
  input repeat_transaction_en,



  output
  output
);

localparam SYMBOL_PER_WORD = DATA_AMM_W/DATA_DDR_W;

logic [ADDR_W - 1:0] addr_reg;
logic [ADDR_W - 1:0] rnd_addr_reg;
logic 

function logic check_data_pattern(  input logic [DATA_W - 1: 0] data,
                                    input logic [7:0]           pattern );

  for( int i = 0; i < DATA_W/8; i++)
    begin
      if( data[DATA_W - 8*i : DATA_W - 7 -8*i] != pattern )
        return 1'b0;
    end

  return 1'b1;

endfunction

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    rnd_addr_reg <= 32'hFF_FF_FF_FF;
  else if( load_rnd_addr_reg )
    rnd_addr_reg <= rnd_addr_store;
  else if( next_rnd_addr_en )
    rnd_addr_reg <= { rnd_addr_reg[30:0], rnd_addr_gen_bit };

assign rnd_addr_gen_bit = rnd_addr[31] ^ rnd_addr[3] ^ rnd_addr[0];

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    rnd_addr_store <= '0;
  else if( store_current_state_sig )
    rnd_addr_store <= rnd_addr_reg;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    test_started <= 1'b0;
  else if( transaction_en_sig )
    test_started <= 1'b1;
  else if( end_of_test_sig )
    test_started <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    address <= '0;
  else if( transaction_en_sig && next_addr_en && ( !waitrequest ) )
    if( csr[1][11:0] == 'd1 )
      if( csr[1][15:13] == 3'b000 )
        address <= csr[2][ADDR_W - 1 : 0];
      else if( csr[1][15:13] == 3'b001 )
        address <= rnd_addr_reg;
      else if( csr[1][15:13] == 3'b010 )
        address <= running_0;
      else if( csr[1][15:13] == 3'b011 )
        address <= running_1;
      else if( csr[1][15:13] == 3'b100 )
        if( test_started == 1'b0 )
          address <= csr[2][ADDR_W - 1 : 0];
        else
          address <= address + 1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    running_0 <= '0;
  else if( reset_state_sig )
    running_0 <= '1 - 1;
  else if( ( csr[1][15:13] == 3'b010 ) && next_addr_en )
    running_0 <= { running_0[ADDR_W - 1 : 0], running_0[ADDR_W] };

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    running_1 <= '0;
  else if( reset_state_sig )
    running_1 <= '0 + 1;
  else if( ( csr[1][15:13] == 3'b011 ) && next_addr_en )
    running_1 <= { running_1[ADDR_W - 1 : 0], running_1[ADDR_W] };

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    rnd_data_reg <= 8'hFF;
  else if( load_data_ptrn_sig )
    rnd_data_reg <= rnd_data_store;
  else if( rnd_data_en )
    rnd_data_reg <= { rnd_data_reg[6:0], rnd_data_gen_bit };

assign rnd_data_gen_bit = rnd_data[6] ^ rnd_data[1] ^ rnd_data[0];

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    burstcount <= '0;
  else if( start_bit_set )
    burstcount <= csr[1][11:0];

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    burst_cnt <= '0;
  else if( start_bit_set )
    burst_cnt <= csr[1][11:0];
  else if( transaction_en_sig )
    if( csr[1][18] == 1'b0 )
      burst_cnt <= burst_cnt - DATA_W/8;
    else
      burst_cnt <= burst_cnt - 1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    burst_cnt_empty <= 1'b0;
  else if( ( burst_cnt < DATA/8 ) && transaction_en_sig )
    burst_cnt_empty <= 1'b1;
  else if( transaction_en_sig )
    burst_cnt_empty <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    byteenable <= '0;
  else if( ( csr[1][18] == 1'b0 ) && start_bit_set )
    byteenable <= '1;
  else if( ( csr[1][18] == 1'b1 ) && transaction_en_sig )
    if( ( csr[1][13:11] == 3'b010 ) || ( csr[1][13:11] == 3'b011 ) )
      for( int i = 0; i < DATA_BYTE; i++ )
        byteenable[i] = ( reg_addr == i );
    else if( burst_cnt > SYMBOL_PER_WORD )
      byteenable <= '1;
    else if( burst_cnt < SYMBOL_PER_WORD )
      for( int i = 0; i < SYMBOL_PER_WORD; i++ )
        if( i < reg_addr[2:0] )
          byteenable <= 1'b1;
        else
          byteenable <= 1'b0;

endmodule
