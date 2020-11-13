Module address_block #(
  parameter CTRL_DATA_W = 64,
  parameter CTRL_ADDR_W = 12,
  parameter AMM_DATA_W  = 512,
  parameter ADDR_TYPE   = BYTE // BYTE or WORD
)( 
  input   rst_i,
  input   clk_i,

  input   start_test_i,
  input   trans_en_i,
  input   trans_type_i, // 0-write, 1-read
  input   next_addr_en_i,

  input   save_start_addr_i,
  input   restore_start_addr_i,

  output  cmd_accepted_o
);

localparam SYMBOL_PER_WORD = DATA_AMM_W/DATA_DDR_W;
localparam BYTE_PER_WORD   = DATA_AMM_W/8;
localparam BYTE_ADDR_W     = clog2( BYTE_PER_WORD );

logic [ADDR_W - 1:0] addr_reg;

generate

  if( ADDR_W <= 8 )
    begin
      logic [7:0] rnd_addr_reg = 8'b1;
      logic [7:0] rnd_addr_reg = 8'b1;
      assign rnd_addr_gen_bit = rnd_addr[31] ^ rnd_addr[3] ^ rnd_addr[0];
    end
  else if( ADDR_W <= 16 )
    begin
      logic [15:0] rnd_addr_reg = 16'b1;
      logic [15:0] rnd_addr_reg = 16'b1;
      assign rnd_addr_gen_bit = rnd_addr[31] ^ rnd_addr[3] ^ rnd_addr[0];
    end
  else if( ADDR_W <= 32 )
    begin
      logic [31:0] rnd_addr_reg = 32'b1;
      logic [31:0] rnd_addr_reg = 32'b1;
      assign rnd_addr_gen_bit = rnd_addr[31] ^ rnd_addr[3] ^ rnd_addr[0];
    end

endgenerate

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    rnd_addr_reg <= 32'hFF_FF_FF_FF;
  else if( restore_start_addr_i )
    rnd_addr_reg <= rnd_addr_store;
  else if( ( csr[1][15:13] == 3'b001 ) && trans_en_i && next_addr_en_i )
    rnd_addr_reg <= { rnd_addr_reg[30:0], rnd_addr_gen_bit };

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    rnd_addr_store <= '0;
  else if( ( csr[1][15:13] == 3'b001 ) && save_dev_state_i )
    rnd_addr_store <= rnd_addr_reg;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    running_0_reg <= 'd0 + 1'b1;
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

generate
  if( ADDR_TYPE == BYTE )
    
  else if( ADDR_TYPE == WORD )

endgenerate

always_comb
  case( csr[1][15:13] )
    3'b000  : decoded_addr = csr[2][ADDR_W - 1 : 0];
    3'b001  : decoded_addr = rnd_addr_reg[ADDR_W - 1 : 0];
    3'b010  : decoded_addr = running_0_reg;
    3'b011  : decoded_addr = running_1_reg;
    3'b100  : decoded_addr = inc_addr_reg;
    default : decoded_addr = (ADDR_W)'bX;
  endcase

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    word_aligned_addr <= 1'b0;
  else if( trans_en_i && next_addr_en_i )
    word_aligned_addr <= ( decoded_addr[BYTE_ADDR_W - 1 : 0] == (BYTE_ADDR_W)'d0 );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    short_burst <= 1'b0;
  else if( trans_en_i && next_addr_en_i )
    short_burst <= ( BYTE_PER_WORD - ( decoded_addr[BYTE_ADDR_W - 1 : 0] + csr[1][BYTE_ADDR_W - 1 : 0] ) );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    low_burst_en <= 1'b0;
  else if( trans_en_i )
    if( ADDR_TYPE == WORD )
      low_burst_en <= ( csr[1][10:0] > 11'd1 );
    else if( ADDR_TYPE == BYTE )
      low_burst_en <= ( byte_transfered  > csr[1][BYTE_PER_WORD : 0] );

assign byte_transfered = ( ( BYTE_PER_WORD ) - decoded_addr[BYTE_ADDR_W - 1 : 0] );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    byte_transfered_reg <= (BYTE_ADDR_W)'b0;
  else if( trans_en_i && next_addr_en_i )
    byte_transfered_reg <= byte_transfered;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    high_burst_en <= 1'b0;
  else if( trans_en_i )
    high_burst_en <= ( csr[1][10 : BYTE_PER_WORD + 1] != 0 );

assign burst_en = ( low_burst_en || high_burst_en );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    address_1 <= (ADDR_W)'b0;
  else if( trans_en_i && next_addr_en_i )
    address_1 <= { decoded_addr[ADDR_W - 1 : BYTE_ADDR_W] , (BYTE_ADDR_W)'b0 };

if( ADDR_TYPE == BYTE )generate
  always_ff @( posedge clk_i, posedge rst_i )
    if( rst_i )
      single_word_mode <= 1'b0;
    else if( trans_en_i )
      single_word_mode <= ( ( csr[1][15:13] == 3'b010 ) || ( csr[1][15:13] == 3'b011 ) );
end if

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    burst_byte_left <= '0;
  else if( trans_en_i )
    burst_byte_left <= ( csr[1][10:0] - byte_transfered );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    burstcount <= '0;
  else if( 2_trans_en )
    burstcount <= csr[1][11:0];

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    burst_cnt <= '0;
  else if( 2_trans_en_i && burst_en )
    if( int_cmd_accepted && !cmd_accepted_o )
      if( ADDR_TYPE == BYTE )
        burst_cnt <= burst_cnt - DATA_W/8;
      else if( ADDR_TYPE == WORD )
        burst_cnt <= burst_cnt - 1;
    else if( !cmd_accepted_o )
      burst_cnt <= csr[1][11:0];

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    burst_cnt_empty <= 1'b0;
  else if( ( burst_cnt < DATA/8 ) && transaction_en_sig )
    burst_cnt_empty <= 1'b1;
  else if( transaction_en_sig )
    burst_cnt_empty <= 1'b0;










always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    cmd_accepted_o <= 1'b0;
  else if( 2_stage_busy )
    cmd_accepted_o <= 1'b0;
  else
    cmd_accepted_o <= 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    2_stage_busy <= 1'b0;
  else if( burst_en )
    2_stage_busy <= 1'b1;
  else
    2_stage_busy <= 1'b0;
  
function logic [DATA_W/8 - 1 : 0] byteenable_ptrn(  input logic [clog2( DATA_W/8 ) - 1 : 0] current_address,
                                                    input logic                             pattern_type     ) // 0-one address, 1-pattern

    for( int i = 0; i < DATA_W/8; i++ )
      if( pattern_type )
        byteenable_ptrn[i] = ( i < current_address );
      else
        byteenable_ptrn[i] = ( i == current_address );

  return byteenable_ptrn;

endfunction

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

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    rnd_data_reg <= 8'hFF;
  else if( load_data_ptrn_sig )
    rnd_data_reg <= rnd_data_store;
  else if( rnd_data_en )
    rnd_data_reg <= { rnd_data_reg[6:0], rnd_data_gen_bit };

assign rnd_data_gen_bit = rnd_data[6] ^ rnd_data[1] ^ rnd_data[0];

endmodule
