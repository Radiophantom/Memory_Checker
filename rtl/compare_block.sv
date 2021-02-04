import settings_pkg::*;

module compare_block (
  input                               clk_i,
  input                               rst_i,

  input                               start_test_i,

  // Avalon-MM interface
  input                               readdatavalid_i,
  input         [AMM_DATA_W - 1 : 0]  readdata_i,

  // transmitter block interface
  input                               cmp_pkt_en_i,
  input  pkt_struct_type              cmp_pkt_struct_i,

  // result block interface
  output logic                        check_result_valid_o,
  output logic                        check_result_o,
  output logic  [CTRL_ADDR_W - 1 : 0] check_error_address_o
);

function logic [BYTE_PER_WORD - 1 : 0] check_ptrn_func( input logic [BYTE_PER_WORD - 1 : 0] check_ptrn,
                                                        input logic [7 : 0]                 data_ptrn,
                                                        input logic [AMM_DATA_W - 1 : 0]    read_data   );
  for( int i = 0; i < BYTE_PER_WORD; i++ )
    if( check_ptrn[i] )
      check_ptrn_func[i] = ( data_ptrn != readdata[7 + i*8 : i*8] );
    else
      check_ptrn_func[i] = 1'b0;
endfunction

function logic [BYTE_ADDR_W - 1 : 0] error_byte_num_func( input logic [BYTE_PER_WORD - 1 : 0] check_vector );
  for( int i = 0; i < BYTE_PER_WORD; i++ )
    if( check_vector[i] )
      error_byte_num_func = i;
endfunction

localparam int PKT_W = $bits( pkt_struct_t );

pkt_struct_type            storage_pkt_struct, check_pkt_struct;
logic                      storage_valid_flg;

logic                      stop_check_flg;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    storage_valid_flg <= 1'b0;
  else
    if( load_checker_stb || stop_checker_flg )
      storage_valid_flg <= 1'b0;
    else
      if( cmp_pkt_en_i )
        storage_valid_flg <= 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    storage_pkt_struct <= PKT_W'( 0 );
  else
    if( cmp_pkt_en_i )
      storage_pkt_struct <= cmp_pkt_struct_i;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    check_pkt_struct <= PKT_W'( 0 );
  else
    if( load_checker_stb )
      check_pkt_struct <= storage_pkt_struct;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    busy_flg <= 1'b0;
  else
    if( load_checker_stb )
      busy_flg <= 1'b1;
    else
      if( pkt_check_complete_stb )
        busy_flg <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    word_cnt <= AMM_BURST_W'( 0 );
  else
    if( load_checker_stb )
      word_cnt <= storage_pkt_struct.burst_word_count;
    else
      if( readdatavalid_i )
        word_cnt <= word_cnt - 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    last_word_flg <= 1'b0;
  else
    if( load_checker_stb )
      last_word_flg <= ( storage_pkt_struct.burst_word_count == 1 );
    else
      if( readdatavalid_i )
        last_word_flg <= ( word_cnt == 2 );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    check_ptrn_vec <= BYTE_PER_WORD'( 0 );
  else
    if( load_checker_stb )
      begin
        if( storage_pkt_struct.burst_word_count == 1 )
          check_ptrn_vec <= ( storage_pkt_struct.start_mask && storage_pkt_struct.end_mask );
        else
          check_ptrn_vec <= storage_pkt_struct.start_mask;
      end
    else
      if( readdatavalid_i )
        if( word_cnt == 2 )
          check_ptrn_vec <= check_pkt_struct.end_mask;
        else
          check_ptrn_vec <= BYTE_PER_WORD{ 1'b1 };

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    readdatavalid_dly <= 1'b0;
  else
    readdatavalid_dly <= readdatavalid_i;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    check_address_reg <= CTRL_ADDR_W'( 0 );
  else
    if( readdatavalid_i )
      check_address_reg <= check_address_cnt;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    check_address_cnt <= ADDR_W'( 0 );
  else
    if( load_checker_stb )
      check_address_cnt <= storage_pkt_struct.word_address;
    else
      if( readdatavalid_i )
        check_address_cnt <= check_address_cnt + 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    stop_checker_flg <= 1'b0;
  else
    if( start_test_i )
      stop_checker_flg <= 1'b0;
    else
      if( readdatavalid_dly && error_check_result )
        stop_checker_flg <= 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    data_ptrn_reg <= '0;
  else
    if( load_checker_stb )
      data_ptrn_reg <= storage_pkt_struct.data_ptrn;
    else
      if( readdatavalid_i && check_pkt_struct.data_ptrn_type )
          data_ptrn_reg <= { data_ptrn_reg[6:0], data_gen_bit };

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    error_check_o <= 1'b0;
  else
    error_check_o <= ( readdatavalid_dly && error_check_result );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    check_vector <= BYTE_PER_WORD'( 0 );
  else
    if( readdatavalid_i )
      check_vector <= check_ptrn_func( check_ptrn_vec, data_ptrn_reg, readdata_i );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    check_error_address_o <= CTRL_ADDR_W'( 0 );
  else
    if( readdatavalid_dly && error_check_result )
      check_error_address_o <= { check_address, error_byte_num };

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    cmp_block_busy_o <= 1'b0;
  else
    cmp_block_busy_o <= ( storage_valid_flg || busy_flg );

assign error_check_result = &( check_vector );
assign error_byte_num = error_byte_func( check_vector );
assign data_gen_bit = ( data_gen_reg[6] ^ data_gen_reg[1] ^ data_gen_reg[0] );

assign pkt_check_complete_stb = ( last_word_flg && readdatavalid_i );
assign load_checker_stb       = ( !busy_flg || pkt_check_complete_stb ) ? ( storage_valid_flg ) :
                                                                          ( 1'b0          );

endmodule
