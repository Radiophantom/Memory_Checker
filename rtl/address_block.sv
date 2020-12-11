typedef struct {
  logic [ADDR_W - 1 : 0]      word_address;
  logic                       op_type;
  logic                       high_burst;
  logic                       low_burst;
  logic [10 : 0]              burst_word_count;
  logic [BYTE_ADDR_W - 1 : 0] start_offset;
  logic [BYTE_ADDR_W - 1 : 0] end_offset;
} transaction_type;

Module address_block #(
  parameter AMM_DATA_W    = 128,
  parameter AMM_ADDR_W    = 12,
  parameter AMM_BURST_W   = 11,
  parameter ADDR_TYPE     = BYTE,
  parameter BYTE_PER_WORD = AMM_DATA_W/8,
  parameter BYTE_ADDR_W   = $clog2( BYTE_PER_WORD ),
  parameter ADDR_W        = ( AMM_ADDR_W - BYTE_ADDR_W )
)( 
  input                                 rst_i,
  input                                 clk_i,

  // Stop test
  input                                 stop_module,
  output                                module_stopped,

  // Control module interface
  input                                 trans_en_i,
  input                                 trans_type_i, // 0-write, 1-read
  input                                 next_addr_en_i,
  input                                 reset_start_addr_i,

  output                                cmd_accepted_o,

  output logic                          operation_valid_o,
  output transaction_type               operation_o
);


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
    if( reset_start_addr_i )
      rnd_addr_reg <= '1;
    else if( trans_en_allowed && next_addr_en_i )
      rnd_addr_reg <= { rnd_addr_reg[ $left( rnd_addr_reg ) - 1 : 0], rnd_addr_gen_bit };

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    running_0_reg <= '0;
  else if( csr[1][15:13] == 3'b010 )
    if( reset_start_addr_i )
      running_0_reg <= ( '1 - 1'b1 );
    else if( trans_en_allowed && next_addr_en_i )
      running_0_reg <= { running_0_reg[ADDR_W - 2 : 0], running_0_reg[ADDR_W - 1] };

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    running_1_reg <= '0;
  else if( csr[1][15:13] == 3'b011 )
    if( reset_start_addr_i )
      running_1_reg <= ( '0 + 1'b1 );
    else if( trans_en_allowed && next_addr_en_i )
      running_1_reg <= { running_1_reg[ADDR_W - 2 : 0], running_1_reg[ADDR_W - 1] };

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    inc_addr_reg <= '0;
  else if( csr[1][15:13] == 3'b100 )
    if( reset_start_addr_i )
      inc_addr_reg <= csr[2][ADDR_W - 1 : 0];
    else if( trans_en_allowed && next_addr_en_i )
      inc_addr_reg <= inc_addr_reg + 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    fix_addr_reg <= '0;
  else if( csr[1][15:13] == 3'b000 )
    if( reset_start_addr_i )
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

assign low_burst  = ( BYTE_PER_WORD - ( decoded_addr[BYTE_ADDR_W - 1 : 0] + csr[1][BYTE_ADDR_W - 1 : 0] ) );
assign high_burst = ( csr[1][10 : BYTE_ADDR_W + 1] != 0 );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    burst_transfered <= '0;
  else if( trans_en_allowed )
    burst_transfered <= ( BYTE_PER_WORD - ( decoded_addr[BYTE_ADDR_W - 1 : 0] ) );

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
    operation_valid_o <= 1'b0;
  else
    operation_valid_o <= cmd_accepted_o;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    op_type <= 1'b0;
  else if( trans_en_allowed && cmd_accepted_o )
    op_type <= trans_type_i;



endmodule
