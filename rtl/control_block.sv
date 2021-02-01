import settings_pkg::*;

module control_block (
  input                       rst_i
  input                       clk_i,

  input                       start_test_i,

  input                       error_check_i,
  input                       cmp_block_busy_i,
  input                       meas_block_busy_i,
  input                       trans_block_busy_i,

  input         [0:1] [31:0]  test_param_reg_i,
  
  input                       cmd_accept_ready_i,

  output logic                write_result_o,

  output logic                op_valid_o,
  output logic                op_type_o, // 0-write, 1-read
  output trans_struct_type    op_pkt_o
);

localparam int PKT_W      = ( ADDR_W + 2*BYTE_ADDR_W + AMM_BURST_W + 1 );
localparam int RND_ADDR_W = $size( rnd_addr_reg );

// csr register casting
logic [11 : 0]              test_count_reg;
test_mode_type              test_type_reg;
addr_mode_type              addr_type_reg;
logic [AMM_BURST_W - 1 : 0] burstcount_csr_reg;
logic [AMM_ADDR_W - 1 : 0]  fix_addr_reg;

assign test_count_reg     = test_param_reg_i[0][31:20];
assign test_type_reg      = test_param_reg_i[0][17 : 16];
assign addr_type_reg      = test_param_reg_i[0][15 : 13];
assign burstcount_csr_reg = test_param_reg_i[0][AMM_BURST_W - 1 : 0];
assign fix_addr_csr_reg   = test_param_reg_i[1][CTRL_ADDR_W - 1 : 0];

// variables declaration
logic [11:0]                cmd_cnt;
logic                       last_trans_flg;
logic                       test_complete_flg;
logic                       test_complete_state;

logic                       rnd_addr_gen_bit;
logic [CTRL_ADDR_W - 1 : 0] running_0_reg;
logic [CTRL_ADDR_W - 1 : 0] running_1_reg;
logic [CTRL_ADDR_W - 1 : 0] inc_addr_reg;
logic [CTRL_ADDR_W - 1 : 0] fix_addr_reg;

logic [AMM_BURST_W - 1 : 0] word_burst_count;
logic                       next_addr_en_stb;
logic                       next_addr_allowed;
logic                       op_en;
logic                       low_burst_en;
logic                       high_burst_en;
logic [BYTE_ADDR_W - 1 : 0] start_offset;
logic [BYTE_ADDR_W - 1 : 0] end_offset;

enum logic [2:0] {
  IDLE_S,
  WRITE_ONLY_S,
  READ_ONLY_S,
  WRITE_WORD_S,
  READ_WORD_S,
  END_TEST_S,
  ERROR_CHECK_S
} state, next_state;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    state <= IDLE_S;
  else if( error_check_i )
    state <= ERROR_CHECK_S;
  else
    state <= next_state;

always_comb
  begin
    next_state = state;
    case( state )
      IDLE_S :
        begin
          if( start_test_i )
            case( test_type )
              READ_ONLY       : next_state = READ_ONLY_S;
              WRITE_ONLY      : next_state = WRITE_ONLY_S;
              WRITE_AND_CHECK : next_state = WRITE_WORD_S;
            endcase
        end
      READ_ONLY_S :
        begin
          if( last_trans_flg && cmd_accept_ready_i )
            next_state = END_TEST_S;
        end
      WRITE_ONLY_S :
        begin
          if( last_trans_flg && cmd_accept_ready_i )
            next_state = END_TEST_S;
        end
      WRITE_WORD_S :
        begin
          if( cmd_accept_ready_i )
            next_state = READ_WORD_S;
        end
      READ_WORD_S :
        begin
          if( last_trans_flg && cmd_accept_ready_i )
            next_state = END_TEST_S;
          else if( cmd_accept_ready_i )
            next_state = WRITE_WORD_S;
        end
      END_TEST_S :
        begin
          if( test_complete_flg )
            next_state = IDLE_S;
        end
      ERROR_CHECK_S :
        begin
          if( test_complete_flg )
            next_state = IDLE_S;
        end
      default :
        begin
          next_state = IDLE_S;
        end
    endcase
  end

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i  )
    cmd_cnt <= 12'( 0 );
  else if( start_test_i )
    cmd_cnt <= test_count_reg;
  else if( op_valid_o && cmd_accept_ready_i )
    cmd_cnt <= cmd_cnt - 1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    last_trans_flg <= 1'b0;
  else if( start_test_i )
    last_trans_flg <= ( test_count_reg == 1 );
  else if( op_valid_o && cmd_accept_ready_i )
    last_trans_flg <= ( cmd_cnt == 2 );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    op_valid_o <= 1'b0;
  else if( error_check_i )
    op_valid_o <= 1'b0;
  else if( trans_en_state && !last_trans_flg )
    op_valid_o <= 1'b1;
  else if( cmd_accept_ready_i )
    op_valid_o <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    op_type_o <= 1'b0;
  else if( trans_en_state )
    case( state )
      WRITE_ONLY_S : op_type_o <= 1'b0;
      READ_ONLY_S  : op_type_o <= 1'b1;
      WRITE_WORD_S : op_type_o <= ( !op_type_o && cmd_accept_ready_i );
      READ_WORD_S  : op_type_o <= !( op_type_o && cmd_accept_ready_i );
      default      : op_type_o <= 1'bX;
    endcase

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    next_addr_en_stb <= 1'b0;
  else
    next_addr_en_stb <= ( op_en && next_addr_allowed );

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

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    fix_addr_reg <= CTRL_ADDR_W'( 0 );
  else if( ( addr_type_reg == FIX_ADDR ) && start_test_i )
    fix_addr_reg <= fix_addr_csr_reg;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    rnd_addr_reg <= RND_ADDR_W'( 0 );
  else if( addr_type_reg == RND_ADDR )
    if( start_test_i )
      rnd_addr_reg <= (RND_ADDR_W){1'b1};
    else if( next_addr_en_stb )
      rnd_addr_reg <= { rnd_addr_reg[$left( rnd_addr_reg ) - 2 : 0], rnd_addr_gen_bit };

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    running_0_reg <= CTRL_ADDR_W'( 0 );
  else if( addr_type_reg == RUN_0 )
    if( start_test_i )
      running_0_reg <= { (CTRL_ADDR_W - 1){1'b1}, 1'b0 };
    else if( next_addr_en_stb )
      running_0_reg <= { running_0_reg[CTRL_ADDR_W - 2 : 0], running_0_reg[CTRL_ADDR_W - 1] };

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    running_1_reg <= CTRL_ADDR_W'( 0 );
  else if( addr_type_reg == RUN_1 )
    if( start_test_i )
      running_1_reg <= { (CTRL_ADDR_W - 1){1'b0}, 1'b1 };
    else if( next_addr_en_stb )
      running_1_reg <= { running_1_reg[CTRL_ADDR_W - 2 : 0], running_1_reg[CTRL_ADDR_W - 1] };

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    inc_addr_reg <= CTRL_ADDR_W'( 0 );
  else if( addr_type_reg == INC_ADDR )
    if( start_test_i )
      inc_addr_reg <= fix_addr_csr_reg;
    else if( next_addr_en_stb )
      inc_addr_reg <= inc_addr_reg + 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    op_pkt_o <= PKT_W'( 0 );
  else if( op_en && trans_en_state )
    begin
      op_pkt_o.word_address     <= decoded_addr[CTRL_ADDR_W - 1 : BYTE_ADDR_W];
      op_pkt_o.high_burst_bits  <= high_burst_bits;
      op_pkt_o.low_burst_bits   <= low_burst_bits;
      op_pkt_o.start_offset     <= start_offset;
      op_pkt_o.end_offset       <= end_offset;
    end

always_comb
  case( test_type_reg )
    FIX_ADDR  : decoded_addr = fix_addr_reg;
    RND_ADDR  : decoded_addr = rnd_addr_reg[CTRL_ADDR_W - 1 : 0];
    RUN_0     : decoded_addr = running_0_reg;
    RUN_1     : decoded_addr = running_1_reg;
    INC_ADDR  : decoded_addr = inc_addr_reg;
    default : decoded_addr = CTRL_ADDR_W'bX;
  endcase

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    write_result_o <= 1'b0;
  else
    write_result_o <= ( test_complete_state && test_complete_flg );

always_comb
  if( ADDR_TYPE == WORD )
    high_burst_bits = burstcount_csr_reg;
  else if( ADDR_TYPE == BYTE )
    high_burst_bits = ( burstcount_csr_reg >> BYTE_ADDR_W );

assign trans_en_state       = ( state == WRITE_ONLY_S ) ||
                              ( state == READ_ONLY_S  ) ||
                              ( state == WRITE_WORD_S ) ||
                              ( state == READ_WORD_S  );

assign next_addr_allowed    = ( state == WRITE_ONLY_S ) ||
                              ( state == WRITE_WORD_S );

assign test_complete_state  = ( state == END_TEST_S ) ||
                              ( state == ERROR_CHECK_S );

assign op_en                = ( !op_valid_o ) || ( op_valid_o && cmd_accept_ready_i );

assign low_burst_bits       = (BYTE_ADDR_W + 1)'( decoded_addr[BYTE_ADDR_W - 1 : 0] - burstcount_csr_reg[BYTE_ADDR_W - 1 : 0] );
assign start_offset         = decoded[BYTE_ADDR_W - 1 : 0];
assign end_offset           = BYTE_ADDR_W'( decoded[BYTE_ADDR_W - 1 : 0] + burstcount_csr_reg[BYTE_ADDR_W - 1 : 0] );

assign test_complete_flg    = ( !cmp_block_busy_i && !meas_block_busy_i && !trans_block_busy_i );

endmodule
