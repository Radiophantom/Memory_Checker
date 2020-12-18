typedef struct {
  logic [ADDR_W - 1      : 0] word_address;
  logic [AMM_BURST_W - 1 : 0] word_burstcount;
  logic [BYTE_ADDR_W - 1 : 0] start_offset;
  logic [BYTE_ADDR_W - 1 : 0] end_offset;
  logic [7 : 0]               data_ptrn;
  logic                       data_rnd; // 0-fix data, 1-rnd data
} compare_pkt_struct;

module compare_block #(
  parameter AMM_DATA_W    = 128,
  parameter AMM_ADDR_W    = 12,
  parameter AMM_BURST_W   = 11,
  parameter BYTE_PER_WORD = ( AMM_DATA_W / 8           ), 
  parameter BYTE_ADDR_W   = $clog2( BYTE_PER_WORD      ),
  parameter ADDR_W        = ( AMM_ADDR_W - BYTE_ADDR_W )
)(
  input                                           clk_i,
  input                                           rst_i,

  input                                           start_test_i,

  // Avalon-MM interface
  input                                           readdatavalid_i,
  input                     [AMM_DATA_W - 1 : 0]  readdata_i,

  // transmitter block interface
  input                                           cmp_pkt_en_i,
  input compare_pkt_struct                        cmp_pkt_struct_i,

  // result block interface
  output logic                                    check_result_valid_o,
  output logic                                    check_result_o,
  output logic              [AMM_ADDR_W - 1 : 0]  check_error_address_o
);

function logic [BYTE_PER_WORD - 1 : 0] check_ptrn_func( input logic [BYTE_PER_WORD - 1 : 0] check_ptrn,
                                                        input logic [7 : 0]                 data_ptrn,
                                                        input logic [AMM_DATA_W - 1 : 0]    readdata   );
  for( int i = 0; i < BYTE_PER_WORD; i++ )
    if( check_ptrn[i] )
      check_ptrn_func[i] = ( data_ptrn == readdata[7 + i*8 : i*8] );
    else
      check_ptrn_func[i] = 1'b1;
endfunction

function logic [BYTE_ADDR_W - 1 : 0] error_byte_num_func( input logic [BYTE_PER_WORD - 1 : 0] check_vector );
  for( int i = 0; i < BYTE_PER_WORD; i++ )
    if( check_vector[i] == 1'b0 )
      error_byte_num_func = i;
endfunction

compare_pkt_struct            storage_reg;

logic                         storage_valid;
logic [BYTE_PER_WORD - 1 : 0] start_offset_mask;
logic [BYTE_PER_WORD - 1 : 0] end_offset_mask;

logic                         stop_checker;

/*
always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    state <= IDLE_S;
  else
    state <= next_state;

always_comb
  next_state = state;
  case( state )
    IDLE_S :
      begin
        if( storage_valid )
          next_state = LOAD_CHECKER_S;
      end 
    LOAD_CHECKER_S :
      begin
        next_state = CHECK_STATE_S;
      end
    CHECK_STATE_S :
      begin
        if( last_word && readdatavalid_i )
          next_state = IDLE_S;
      end
    default :
      begin
        next_state = IDLE_S;
      end
  endcase
*/

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    stop_checker <= 1'b0;
  else if( readdatavalid_reg && !check_vector_result )
    stop_checker <= 1'b1;
  else if( start_test_i )
    stop_checker <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    storage_valid <= 1'b0;
  else if( load_checker || stop_checker )
    storage_valid <= 1'b0;
  else if( cmp_pkt_en_i )
    storage_valid <= 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    storage_reg <= { '0, '0, '0, '0, '0, '0  };
  else if( cmp_pkt_en_i )
    storage_reg <= cmp_pkt_struct_i;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    busy_flag <= 1'b0;
  else if( last_word && readdatavalid_i )
    busy_flag <= 1'b0;
  else if( load_checker )
    busy_flag <= 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    start_offset_mask <= '0;
  else if( load_checker )
    start_offset_mask <= byteenable_ptrn( 1'b1, storage_reg.start_offset, 1'b0, storage_reg.end_offset );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    end_offset_mask <= '0;
  else if( load_checker )
    end_offset_mask <= byteenable_ptrn( 1'b0, storage_reg.start_offset, 1'b1, storage_reg.end_offset );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    word_cnt <= '0;
  else if( load_checker )
    word_cnt <= storage_reg.word_burstcount;
  else if( readdatavalid_i )
    word_cnt <= word_cnt - 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    check_address <= '0;
  else if( load_checker )
    check_address <= storage_reg.word_address;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    data_rnd_flag <= 1'b0;
  else if( load_checker )
    data_rnd_flag <= storage_reg.data_rnd;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    first_word <= 1'b0;
  else if( load_checker )
    first_word <= 1'b1;
  else if( readdatavalid_i )
    first_word <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    last_word <= 1'b0;
  else if( load_checker )
    last_word <= ( storage_reg.word_burstcount == (AMM_BURST_W)'d1 );
  else if( readdatavalid_i )
    last_word <= ( storage_reg.word_burstcount == (AMM_BURST_W)'d2 );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    data_gen_reg <= '0;
  else if( load_checker )
    data_gen_reg <= cmp_data_ptrn_i;
  else if( readdatavalid_i && data_rnd_flag )
    data_gen_reg <= { data_gen_reg[6:0], data_gen_bit };

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    gen_ptrn <= '0;
  else if( load_checker_reg || readdatavalid_i )
    case( {first_word, last_word} )
      2'b10   : gen_ptrn <= start_offset_mask;
      2'b01   : gen_ptrn <= end_offset_mask;
      2'b11   : gen_ptrn <= start_offset_mask && end_offset_mask;
      default : gen_ptrn <= (BYTE_PER_WORD)'bX;
    endcase

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    last_word_reg <= 1'b0;
  else if( readdatavalid_i && last_word )
    last_word_reg <= 1'b1;
  else
    last_word_reg <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    check_valid_o <= 1'b0;
  else if( last_word_reg )
    check_valid_o <= 1'b1;
  else if( readdatavalid_reg && !check_vector_result )
    check_valid_o <= 1'b1;
  else
    check_valid_o <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    load_checker_reg <= 1'b0;
  else
    load_checker_reg <= load_checker;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    check_result_o <= 1'b0;
  else if( check_result_allowed )
    check_result_o <= check_vector_result;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    check_vector <= '0;
  else if( readdatavalid_i )
    check_vector <= check_ptrn_func( gen_ptrn, data_gen_reg, readdata_i );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    readdatavalid_reg <= 1'b0;
  else
    readdatavalid_reg <= readdatavalid_i;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    check_error_address_o <= '0;
  else if( check_result_allowed )
    check_error_address_o <= { check_address, error_byte_num };

assign check_result_allowed = last_word_reg || ( readdatavalid_reg && !check_vector_result );

assign error_byte_num = error_byte_func( check_vector );
assign check_vector_result = &( check_vector );
assign data_gen_bit = ( data_gen_reg[6] ^ data_gen_reg[1] ^ data_gen_reg[0] );
assign load_checker = !busy_flag && storage_valid;

endmodule
