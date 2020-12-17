
module compare_block #(

)(
  // Avalon-MM interface
  input                               readdata_valid_i,
  input         [AMM_DATA_W - 1 : 0]  readdata_i,

  // transmitter block interface
  input                               valid_cmp_en_i,
  input         [BYTE_ADDR_W - 1 : 0] start_offset_i,
  input         [BYTE_ADDR_W - 1 : 0] end_offset_i,
  input         [ADDR_W - 1 : 0]      address_i,
  input         [AMM_BURST_W - 1 : 0] burst_count_i,
  input         [7 : 0]               data_ptrn_i,

  // result block interface
  output logic                        check_valid_o,
  output logic                        check_result_o,
  output logic  [AMM_ADDR_W - 1 : 0]  error_address_o
);

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    valid_storage <= 1'b0;
  else if( valid_cmp_en_i )
    valid_storage <= 1'b1;
  else if( load_checker )
    valid_storage <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    storage_reg <= '0;
  else if( valid_cmp_en_i )
    storage_reg <= { start_offset_i, end_offset_i, address_i, burst_count_i, data_ptrn_i };

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    start_offset_mask <= '0;
  else if( load_checker )
    start_offset_mask <= byteenable_ptrn( 1'b1, storage_reg[$left(storage_reg):BYTE_ADDR_W], 1'b0, storage_reg[sdfsdf:sadfasdf] );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    end_offset_mask <= '0;
  else if( load_checker )
    end_offset_mask <= byteenable_ptrn( 1'b0, storage_reg[$left(storage_reg):BYTE_ADDR_W], 1'b1, storage_reg[sdfsdf:sadfasdf] );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    word_cnt <= '0;
  else if( load_checker )
    word_cnt <= storage_reg[asdfasdf:asdfsd];
  else if( readdata_valid_i )
    word_cnt <= word_cnt - 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    busy_flag <= 1'b0;
  else if( busy_flag )
    busy_flag <= !( last_word && readdata_valid_i );
  else
    busy_flag <= load_checker;
    
always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    last_word <= 1'b0;
  else if( load_checker )
    last_word <= ( storage_reg[asddf:asdfsdf] == (sdfs)'d1 );
  else if( readdata_valid_i )
    last_word <= ( storage_reg[asdf:asdf] == (sdfs)'d2 );

assign load_checker = ( !busy_flag && valid_storage );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    data_gen_reg <= '0;
  else if( load_checker )
    data_gen_reg <= storage_reg[asdf:asdf]; 
  else if( get_data_ptrn )
    data_gen_reg <= { data_gen_reg[6:0], data_gen_bit };

assign data_gen_bit = ( data_gen_reg[6] ^ data_gen_reg[1] ^ data_gen_reg[0] );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    first_word <= 1'b0;
  else if( load_checker )
    first_word <= 1'b1;
  else if( readdata_valid_i )
    first_word <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    gen_ptrn <= '0;
  else if( get_data_ptrn )
    case( {first_word, last_word} )
      2'b10   : gen_ptrn <= start_offset_mask;
      2'b01   : gen_ptrn <= end_offset_mask;
      2'b11   : gen_ptrn <= start_offset_mask && end_offset_mask;
      default : gen_ptrn <= (sdfa)'bX;
    endcase

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    ptrn_check_result <= 1'b0;
  else if( readdata_valid_i )
    ptrn_check_result <= &( check_ptrn_func( gen_ptrn, data_gen_reg, readdata_i ) );
    
function logic [BYTE_PER_WORD - 1 : 0] check_ptrn_func( input logic [BYTE_PER_WORD - 1 : 0] ptrn,
                                                        input logic [7:0]                   data_ptrn,
                                                        input logic [AMM_DATA_W - 1 : 0]    readdata   );

  for( int i=0; i<BYTE_PER_WORD; i++ )
    if( ptrn[i] == 1'b1 )
      check_ptrn_func[i] = ( data_ptrn == readdata[i*8 - 1 : i*8 - 8] );
    else
      check_ptrn_func[i] = 1'b1;
   
endmodule
