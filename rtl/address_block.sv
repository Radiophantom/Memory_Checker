Module address_block #(
  parameter CTRL_DATA_W = 64,
  parameter CTRL_ADDR_W = 12,
  parameter AMM_DATA_W  = 512
)( 
  input   rst_i,
  input   clk_i,

  input   trans_en_i,
  input   trans_type_i, // 0-write, 1-read
  input   next_addr_en_i,

  input   save_dev_state_i,
  input   restore_dev_state_i,

  output  cmd_accepted_o
);

localparam SYMBOL_PER_WORD = DATA_AMM_W/DATA_DDR_W;

logic [ADDR_W - 1:0] addr_reg;
logic [ADDR_W - 1:0] rnd_addr_reg = '1;
logic 

function logic [DATA_W/8 - 1 : 0] byteenable_ptrn(  input logic [clog2( DATA_W/8 ) - 1 : 0] current_address,
                                                    input logic                             pattern_type     ) // 0-one address, 1-pattern

  if( pattern_type )
    for( int i = 0; i < DATA_W/8; i++ )
      byteenable_ptrn[i] = ( i < current_address );
  else
    for( int i = 0; i < DATA_W/8; i++ )
      byteenable_ptrn[i] = ( i == current_address );

  return byteenable_ptrn;

endfunction

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    rnd_addr_reg <= 32'hFF_FF_FF_FF;
  else if( restore_dev_state_i )
    rnd_addr_reg <= rnd_addr_store;
  else if( ( csr[1][15:13] == 3'b001 ) && trans_en_i && next_addr_en_i )
    rnd_addr_reg <= { rnd_addr_reg[30:0], rnd_addr_gen_bit };

assign rnd_addr_gen_bit = rnd_addr[31] ^ rnd_addr[3] ^ rnd_addr[0];

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    rnd_addr_store <= '0;
  else if( ( csr[1][15:13] == 3'b001 ) && save_dev_state_i )
    rnd_addr_store <= rnd_addr_reg;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    running_0_reg <= '0;
  else if( csr[1][15:13] == 3'b010 )
    if( start_test_i || restore_dev_state_i )
      running_0_reg <= '1 - 1'b1;
    else if( trans_en_i && next_addr_en_i )
      running_0_reg <= { running_0_reg[ADDR_W - 2 : 0], running_0_reg[ADDR_W - 1] };

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    running_1_reg <= '0;
  else if( csr[1][15:13] == 3'b011 )
    if( start_test_i || restore_dev_state_i )
      running_1_reg <= '0 + 1'b1;
    else if( trans_en_i && next_addr_en_i )
      running_1_reg <= { running_1_reg[ADDR_W - 2 : 0], running_1_reg[ADDR_W - 1] };

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    inc_addr_reg <= '0;
  else if( csr[1][15:13] == 3'b100 )
    if( start_test_i || restore_dev_state_i )
      inc_addr_reg <= csr[2][ADDR_W - 1 : 0];
    else if( trans_en_i && next_addr_en_i )
      inc_addr_reg <= inc_addr_reg + 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    address <= '0;
  else if( ( !waitrequest ) && trans_en_i && next_addr_en_i && burst_flag )
    if( csr[1][15:13] == 3'b000 )
      address <= csr[2][ADDR_W - 1 : clog2( DATA_W/8 )];
    else if( csr[1][15:13] == 3'b001 )
      address <= rnd_addr_reg[ADDR_W - 1 : clog2( DATA_W/8 )];
    else if( csr[1][15:13] == 3'b010 )
      address <= running_0_reg[ADDR_W - 1 : clog2( DATA_W/8 )];
    else if( csr[1][15:13] == 3'b011 )
      address <= running_1_reg[ADDR_W - 1 : clog2( DATA_W/8 )];
    else if( csr[1][15:13] == 3'b100 )
      address <= inc_addr_reg[ADDR_W - 1 : clog2( DATA_W/8 )];

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
