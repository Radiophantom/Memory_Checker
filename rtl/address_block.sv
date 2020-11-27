Module address_block #(
  parameter AMM_DATA_W  = 128,
  parameter AMM_ADDR_W  = 12,
  parameter ADDR_TYPE   = BYTE, // "BYTE" or "WORD"

  parameter CTRL_DATA_W = 64,
  parameter CTRL_ADDR_W = 12
)( 
  input                                 rst_i,
  input                                 clk_i,

  // Control module interface
  input                                 trans_en_i,
  input                                 trans_type_i, // 0-write, 1-read
  input                                 next_addr_en_i,
  input                                 restore_start_addr_i,

  output                                cmd_accepted_o,

  // Compare module interface
  input                                 block_rd_trans_i,
  
  output  logic                         cmp_addr_en_o,
  output  logic [AMM_ADDR_W - 1 : 0]    check_addr_o,
  output  logic [10 : 0]                burst_length_o,
  output  logic [7 : 0]                 check_data_o,

  // Avalon-MM output interface
  input                                 readdatavalid_i,
  input   logic [AMM_DATA_W - 1 : 0]    readdata_i,
  input                                 waitrequest_i,

  output  logic [AMM_ADDR_W - 1 : 0]    address_o,
  output                                read_o,
  output                                write_o,
  output  logic [AMM_DATA_W - 1 : 0]    writedata_o,
  output  logic [10 : 0]                burstcount_o,
  output  logic [AMM_DATA_W/8 - 1 : 0]  byteenable_o
);

localparam SYMBOL_PER_WORD = AMM_DATA_W/CTRL_DATA_W;
localparam BYTE_PER_WORD   = AMM_DATA_W/8;
localparam BYTE_ADDR_W     = $clog2( BYTE_PER_WORD );

logic rnd_addr_gen_bit;
logic [AMM_ADDR_W - 1 : 0] running_0_reg;
logic [AMM_ADDR_W - 1 : 0] running_1_reg;
logic [AMM_ADDR_W - 1 : 0] inc_addr_reg;
logic [AMM_ADDR_W - 1 : 0] fix_addr_reg;

generate
  if( CTRL_ADDR_W <= 8 )
    begin
      logic [7:0] rnd_addr_reg;
      assign rnd_addr_gen_bit = rnd_addr[7] ^ rnd_addr[5] ^ rnd_addr[4] ^ rnd_addr[3];
    end
  else if( CTRL_ADDR_W <= 16 )
    begin
      logic [15:0] rnd_addr_reg;
      assign rnd_addr_gen_bit = rnd_addr[16] ^ rnd_addr[7] ^ rnd_addr[1];
    end
  else if( CTRL_ADDR_W <= 32 )
    begin
      logic [31:0] rnd_addr_reg;
      assign rnd_addr_gen_bit = rnd_addr[31] ^ rnd_addr[21] ^ rnd_addr[1] ^ rnd_addr[0];
    end
endgenerate

assign trans_en_allowed = ( trans_en_i && cmd_accepted_o );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    rnd_addr_reg <= '0;
  else if( csr[1][15:13] == 3'b001 )
    if( restore_start_addr_i )
      rnd_addr_reg <= '1;
    else if( trans_en_allowed && next_addr_en_i )
      rnd_addr_reg <= { rnd_addr_reg[ $left( rnd_addr_reg ) - 1 : 0], rnd_addr_gen_bit };

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    running_0_reg <= '0;
  else if( csr[1][15:13] == 3'b010 )
    if( restore_start_addr_i )
      running_0_reg <= ( '1 - 1'b1 );
    else if( trans_en_allowed && next_addr_en_i )
      running_0_reg <= { running_0_reg[ADDR_W - 2 : 0], running_0_reg[ADDR_W - 1] };

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    running_1_reg <= '0;
  else if( csr[1][15:13] == 3'b011 )
    if( restore_start_addr_i )
      running_1_reg <= ( '0 + 1'b1 );
    else if( trans_en_allowed && next_addr_en_i )
      running_1_reg <= { running_1_reg[ADDR_W - 2 : 0], running_1_reg[ADDR_W - 1] };

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    inc_addr_reg <= '0;
  else if( csr[1][15:13] == 3'b100 )
    if( restore_start_addr_i )
      inc_addr_reg <= csr[2][ADDR_W - 1 : 0];
    else if( trans_en_allowed && next_addr_en_i )
      inc_addr_reg <= inc_addr_reg + 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    fix_addr_reg <= '0;
  else if( csr[1][15:13] == 3'b000 )
    if( restore_start_addr_i )
      fix_addr_reg <= csr[2][ADDR_W - 1 : 0];

always_comb
  case( csr[1][15:13] )
    3'b000  : decoded_addr = fix_addr_reg;
    3'b001  : decoded_addr = rnd_addr_reg[ADDR_W - 1 : 0];
    3'b010  : decoded_addr = running_0_reg;
    3'b011  : decoded_addr = running_1_reg;
    3'b100  : decoded_addr = inc_addr_reg;
    default : decoded_addr = (ADDR_W)'bX;
  endcase

assign simple_burst = ( BYTE_PER_WORD - ( decoded_addr[BYTE_ADDR_W - 1 : 0] + csr[1][BYTE_ADDR_W - 1 : 0] ) );
assign long_burst   = ( csr[1][10 : BYTE_ADDR_W + 1] != 0 );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    burst_en <= 1'b0;
  else if( trans_en_allowed )
    burst_en <= ( simple_burst || long_burst );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    burst_transfered <= '0;
  else if( trans_en_allowed )
    burst_transfered <= ( BYTE_PER_WORD - ( decoded_addr[BYTE_ADDR_W - 1 : 0] ) );

assign byte_bound = ( BYTE_PER_WORD - decoded_addr[BYTE_ADDR_W - 1 : 0] - csr[1][BYTE_ADDR_W - 1 : 0] );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    burst_left <= '0;
  else if( trans_en_allowed )
    if( byte_ )
      burst_left <= ( csr[1][10 : BYTE_ADDR_W] + 'd1 );
    else
      burst_left <= ( csr[1][10 : BYTE_ADDR_W] + 'd2 );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    address_aligned <= (ADDR_W)'b0;
  else if( trans_en_allowed && next_addr_en_i )
    address_aligned <= { decoded_addr[ADDR_W - 1 : BYTE_ADDR_W] , (BYTE_ADDR_W)'b0 };

//-------------------------------------------------------------------------------- 

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    cmd_accepted_o <= 1'b0;
  else if( cmd_accepted_o == 1'b0 )
    cmd_accepted_o <= ( burst_cnt_empty && !waitrequest_i );
  else if( cmd_accepted_o == 1'b1 )
    cmd_accepted_o <= ( !burst_en && waitrequest_i );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    trans_to_ctrl <= 1'b0;
  else
    trans_to_ctrl <= cmd_accepted_o;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    op_type <= 1'b0;
  else if( trans_en_allowed && cmd_accepted_o )
    op_type <= trans_type_i;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    burstcount_o <= '0;
  else if( trans_to_ctrl )
    if( op_type  == 1'b0 )
      burstcount_o <= csr[1][11:0];
    else
      burstcount_o <=  burst_left;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    burst_cnt <= '0;
  else if( burst_en )
    if( trans_to_ctrl )
      burst_cnt <= ( csr[1][10:0] - burst_transfered );
    else if( !waitrequest_i )
      if( ADDR_TYPE == BYTE )
        burst_cnt <= burst_cnt - BYTE_PER_WORD; 
      else if( ADDR_TYPE == WORD )
        burst_cnt <= burst_cnt - 1;

// now will be last transaction, but it not done yet (simultaneously with last valid operation)
always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    burst_cnt_empty <= 1'b0;
  else if( ADDR_TYPE == BYTE )
    burst_cnt_empty <= ( write_o || read_o ) && ( burst_cnt <= BYTE_PER_WORD );
  else if( ADDR_TYPE == WORD )
    burst_cnt_empty <= ( write_o || read_o ) && ( burst_cnt == 'd1 );

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
  else if( csr[1][12] == 1'b0 )
    if( restore_start_addr_i )
      rnd_data_reg <= csr[3][7:0];
  else if( csr[1][12] == 1'b1 )
    if( restore_start_addr_i )
      rnd_data_reg <= 8'hFF;
    else if( load_data_en )
      rnd_data_reg <= { rnd_data_reg[6:0], rnd_data_gen_bit };

assign rnd_data_gen_bit = rnd_data[6] ^ rnd_data[1] ^ rnd_data[0];

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    writedata_o <= '0;
  else if( load_data_en )
    writedata_o <= { (BYTE_PER_WORD){ rnd_data_reg } };

endmodule
