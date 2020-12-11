typedef struct {
  logic [ADDR_W - 1 : 0]      word_address;
  logic                       high_burst;
  logic                       low_burst;
  logic [AMM_BURST_W - 1 : 0] word_burst_count;
  logic [BYTE_ADDR_W - 1 : 0] start_offset;
  logic [BYTE_ADDR_W - 1 : 0] end_offset;
} transaction_type;

module control_block #(
  parameter AMM_DATA_W    = 128,
  parameter AMM_ADDR_W    = 12,
  parameter AMM_BURST_W   = 11,
  parameter ADDR_TYPE     = BYTE,
  parameter BYTE_PER_WORD = AMM_DATA_W/8,
  parameter BYTE_ADDR_W   = $clog2( BYTE_PER_WORD ),
  parameter ADDR_W        = ( AMM_ADDR_W - BYTE_ADDR_W )
)
(
  input               rst_i,
  input               clk_i,

  input               start_test_i,

  input               stop_test_i,

  input   [31:0][2:0] CSR_reg_i,
  
  input               cmd_accept_ready_i,

  output              transaction_en_o,
  output              transaction_type_o, // 0-write, 1-read

  output logic                          operation_valid_o,
  output transaction_type               operation_o
);

typedef enum logic [2:0] { // may be don't declare the width of type
  IDLE_S,
  WRITE_ONLY_S,
  READ_ONLY_S,
  WRITE_WORD_S,
  READ_WORD_S,
  ERROR_CHECK_WORD_S
} state, next_state;

logic [6:0] cmd_cnt;
logic rnd_addr_gen_bit;
logic [AMM_ADDR_W - 1 : 0] running_0_reg;
logic [AMM_ADDR_W - 1 : 0] running_1_reg;
logic [AMM_ADDR_W - 1 : 0] inc_addr_reg;
logic [AMM_ADDR_W - 1 : 0] fix_addr_reg;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    state <= IDLE_S;
  else if( stop_test_i )
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
            case( CSR_reg_i[0][17:16] )
              2'b01   : next_state = READ_ONLY_S;
              2'b10   : next_state = WRITE_ONLY_S;
              2'b11   : next_state = WRITE_WORD_S;
              // check if "default" word enable
            endcase
        end
      READ_ONLY_S :
        begin
          if( last_transaction && cmd_accept_ready_i )
            next_state = IDLE_S;
        end
      WRITE_ONLY_S :
        begin
          if( last_transaction && cmd_accept_ready_i )
            next_state = IDLE_S;
        end
      WRITE_WORD_S :
        begin
          if( cmd_accept_ready_i )
            next_state = READ_WORD_S;
        end
      READ_WORD_S :
        begin
          if( last_transaction && cmd_accept_ready_i )
            next_state = WRITE_WORD_S;
        end
      ERROR_CHECK_S :
        begin
          if( cmd_accept_ready_i )
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
    cmd_cnt <= 0;
  else if( start_test_i )
    cmd_cnt <= CSR_reg_i[0][31:20];
  else if( cmd_accept_ready_i )
    cmd_cnt <= cmd_cnt - 1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    last_transaction <= 1'b0;
  else if( start_test_i )
    last_transaction <= ( CSR_reg_i[0][31:20] == 12'd1 ); // check if no repeat cmd enable
  else if( ( cmd_cnt == 2 ) && cmd_accept_ready_i )
    last_transaction <= 1'b1;
  else if( cmd_accept_ready_i )
    last_transaction <= 1'b0;

assign transaction_en_state = ( state == WRITE_ONLY_S     ) ||
                              ( state == READ_ONLY_S      ) ||
                              ( state == WRITE_ONE_WORD_S ) ||
                              ( state == READ_ONE_WORD_S  );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    trans_en_o <= 1'b0;
  else if( stop_test_i )
    trans_en_o <= 1'b0;
  else if( transaction_en_state && !last_transaction )
    trans_en_o <= 1'b1;
  else if( transaction_en_state && cmd_accept_ready_i )
    trans_en_o <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    trans_type_o <= 1'b0;
  else if( state == WRITE_ONLY_S )
    trans_type_o <= 1'b0;
  else if( state == READ_ONLY_S )
    trans_type_o <= 1'b1;
  else if( ( state == WRITE_ONE_WORD_S ) && cmd_accept_ready_i )
    trans_type_o <= 1'b1;
  else if( ( state == READ_ONE_WORD_S ) && cmd_accept_ready_i )
    trans_type_o <= 1'b0;

// address generate and decode -------------------------------------------------------------------------

generate
  if( AMM_ADDR_W <= 8 )
    begin
      logic [7:0] rnd_addr_reg;
      assign rnd_addr_gen_bit = rnd_addr[7] ^ rnd_addr[5] ^ rnd_addr[4] ^ rnd_addr[3];
    end
  else if( AMM_ADDR_W <= 16 )
    begin
      logic [15:0] rnd_addr_reg;
      assign rnd_addr_gen_bit = rnd_addr[16] ^ rnd_addr[7] ^ rnd_addr[1];
    end
  else if( AMM_ADDR_W <= 32 )
    begin
      logic [31:0] rnd_addr_reg;
      assign rnd_addr_gen_bit = rnd_addr[31] ^ rnd_addr[21] ^ rnd_addr[1] ^ rnd_addr[0];
    end
endgenerate

assign next_addr_en = ( ( state == WRITE_ONLY_S ) && cmd_accept_ready_i ) ||
                      ( ( state == WRITE_WORD_S ) && cmd_accept_ready_i );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    rnd_addr_reg <= '1;
  else if( ( CSR_reg_i[0][15:13] == 3'b001 ) && next_addr_en )
    rnd_addr_reg <= { rnd_addr_reg[ $left( rnd_addr_reg ) - 2 : 0], rnd_addr_gen_bit };

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    running_0_reg <= ( '1 - 1'b1 );
  else if( ( CSR_reg_i[0][15:13] == 3'b010 ) && next_addr_en )
    running_0_reg <= { running_0_reg[ADDR_W - 2 : 0], running_0_reg[ADDR_W - 1] };

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    running_1_reg <= ( '0 + 1'b1 );
  else if( ( CSR_reg_i[0][15:13] == 3'b011 ) && next_addr_en )
    running_1_reg <= { running_1_reg[ADDR_W - 2 : 0], running_1_reg[ADDR_W - 1] };

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    inc_addr_reg <= '0;
  else if( CSR_reg_i[0][15:13] == 3'b100 )
    if( start_test_i )
      inc_addr_reg <= CSR_reg_i[1][ADDR_W - 1 : 0];
    else if( next_addr_en )
      inc_addr_reg <= inc_addr_reg + 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    fix_addr_reg <= '0;
  else if( start_test_i && ( CSR_reg_i[0][15:13] == 3'b000 ) )
    fix_addr_reg <= CSR_reg_i[1][ADDR_W - 1 : 0];

always_comb
  case( CSR_reg_i[0][15:13] )
    3'b000  : decoded_addr = fix_addr_reg;
    3'b001  : decoded_addr = rnd_addr_reg[ADDR_W - 1 : 0];
    3'b010  : decoded_addr = running_0_reg;
    3'b011  : decoded_addr = running_1_reg;
    3'b100  : decoded_addr = inc_addr_reg;
    default : decoded_addr = (ADDR_W)'bX;
  endcase

assign low_burst  = ( ( BYTE_PER_WORD - decoded_addr[BYTE_ADDR_W - 1 : 0]  ) - CSR_reg_i[1][BYTE_ADDR_W - 1 : 0] ) <= 0 );
assign high_burst = ( CSR_reg_i[1][10 : BYTE_ADDR_W + 1] != 0 );

assign start_offset = decoded[BYTE_ADDR_W - 1 : 0];
assign end_offset   = ( decoded[BYTE_ADDR_W - 1 : 0] + CSR_reg_i[1][BYTE_ADDR_W - 1 : 0] - 1'b1 );

assign word_burst_count = CSR_reg_i[1][10 : BYTE_ADDR_W + 1];

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    begin
      operation_o.word_address <= (ADDR_W)'b0;
      operation_o.high_burst   <= 1'b0;
      operation_o.low_burst    <= 1'b0;
      operation_o.word_burst_count <= (AMM_BURST_W)'d0;
      operation_o.start_offset  <= (BYTE_ADDR_W)'d0;
      operation_o.end_offset    <= (BYTE_ADDR_W + 1)'d0;
    end
  else if( next_addr_en )
    begin
      operation_o.word_address      <= { decoded_addr[ADDR_W - 1 : BYTE_ADDR_W] , (BYTE_ADDR_W)'b0 };
      operation_o.high_burst        <= high_burst;
      operation_o.low_burst         <= low_burst;
      operation_o.word_burst_count  <= word_burst_count;
      operation_o.start_offset      <= start_offset;
      operation_o.end_offset        <= end_offset;
    end

endmodule
