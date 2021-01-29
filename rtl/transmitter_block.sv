module transmitter_block #(
  parameter int AMM_DATA_W    = 128,
  parameter int AMM_ADDR_W    = 12,
  parameter int AMM_BURST_W   = 11,
  parameter int ADDR_TYPE     = BYTE,

  parameter int BYTE_PER_WORD = AMM_DATA_W/8,
  parameter int BYTE_ADDR_W   = $clog2( BYTE_PER_WORD ),
  parameter int ADDR_W        = ( AMM_ADDR_W - BYTE_ADDR_W )
)( 
  input                                  rst_i,
  input                                  clk_i,

  // Address block interface
  input                                  op_valid_i,
  input                                  op_type_i,
  input  transaction_type                op_pkt_i,
  input          [0:1] [31 : 0]          test_param_reg_i[0],
  
  output logic                           cmd_accept_ready_o,
  output logic                           trans_block_busy_o,

  // Avalon-MM output interface
  input                                  readdatavalid_i,
  input  logic   [AMM_DATA_W - 1    : 0] readdata_i,
  input                                  waitrequest_i,

  output logic   [AMM_ADDR_W - 1    : 0] address_o,
  output logic                           read_o,
  output logic                           write_o,
  output logic   [AMM_DATA_W - 1    : 0] writedata_o,
  output logic   [AMM_BURST_W - 1   : 0] burstcount_o,
  output logic   [BYTE_PER_WORD - 1 : 0] byteenable_o
);

function logic [BYTE_PER_WORD - 1 : 0] byteenable_ptrn( input logic                       start_offset_en,
                                                        input logic [BYTE_ADDR_W - 1 : 0] start_offset,
                                                        input logic                       end_offset_en,
                                                        input logic [BYTE_ADDR_W     : 0] end_offset      );
  for( int i = 0; i < BYTE_PER_WORD; i++ )
    case( {start_offset_en, end_offset_en} )
      2'b01   : byteenable_ptrn[i] = ( i <= end_offset   );
      2'b10   : byteenable_ptrn[i] = ( i >= start_offset );
      2'b11   : byteenable_ptrn[i] = ( i >= start_offset ) && ( i <= end_offset );
      default : byteenable_ptrn[i] = 1'b1;
    endcase
endfunction

logic [AMM_BURST_W - 1 : 0] burst_cnt;
logic                       write_complete_stb;
logic                       start_trans_stb;
logic                       last_transaction_flg;
logic                       cur_op_type;
transaction_type            cur_op_pkt;
logic                       low_burst_en_flg;
logic                       high_burst_en_flg;
logic                       trans_pkt_en;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    trans_pkt_en <= 1'b0;
  else if( error_check_i )
    trans_pkt_en <= 1'b0;
  else if( cmd_accept_ready_o )
    trans_pkt_en <= op_valid_i;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    high_burst_en_flg <= 1'b0;
  else if( cmd_accept_ready_o && op_valid_i )
    high_burst_en_flg <= ( op_pkt_i.word_burst_count > 1 );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    low_burst_en_flg <= 1'b0;
  else if( cmd_accept_ready_o && op_valid_i )
    low_burst_en_flg <= ( op_pkt_i.low_burst_bits < 0 );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    cur_op_pkt <= $size(op_pkt_i)'( 0 );
  else if( cmd_accept_ready_o && op_valid_i )
    cur_op_pkt <= op_pkt_i;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    cur_op_type <= 1'b0;
  else if( cmd_accept_ready_o && op_valid_i )
    cur_op_type <= op_type_i;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    cmd_accept_ready_o <= 1'b0;
  else if( cmd_accept_ready_o )
    cmd_accept_ready_o <= ( !trans_pkt_en );
  else if( read_o )
    cmd_accept_ready_o <= ( !waitrequest_i );
  else if( write_o )
    cmd_accept_ready_o <= ( last_transaction_flg && !waitrequest_i );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    address_o <= AMM_ADDR_W'( 0 );
  else if( start_trans_stb )
    address_o <= ( cur_op_pkt.word_address << BYTE_ADDR_W );
    // address_o <= { cur_op_pkt.word_address, BYTE_ADDR_W'( 0 ) };

generate
  if( ADDR_TYPE == BYTE )
    begin
      always_ff @( posedge clk_i, posedge rst_i )
        if( rst_i )
          burstcount_o <= AMM_BURST_W'( 0 );
        else if( start_trans_stb )
          burstcount_o <= test_param_reg_i[0][AMM_BURST_W - 1 : 0];

      always_ff @( posedge clk_i, posedge rst_i )
        if( rst_i )
          byteenable_o <= BYTE_PER_WORD'( 0 );
        else if( start_trans_stb )
          if( cur_op_type )
            byteenable_o <= BYTE_PER_WORD{ 1'b1 };
          else
            byteenable_o <= byteenable_ptrn( 1'b1, cur_op_pkt.start_offset, burst_en_flg, cur_op_pkt.end_offset );
        else if( write_complete_stb )
          byteenable_o <= byteenable_ptrn( 1'b0, cur_op_pkt.start_offset, last_transaction_flg, cur_op_pkt.end_offset );

      always_ff @( posedge clk_i, posedge rst_i )
        if( rst_i )
          burst_cnt <= AMM_BURST_W'( 0 );
        else if( start_trans_stb )
          burst_cnt <= cur_op_pkt.burst_word_count;
        else if( write_complete_stb )
          burst_cnt <= burst_cnt - 1'b1;
    end
  else if( ADDR_TYPE == WORD )
    begin
      always_ff @( posedge clk_i, posedge rst_i )
        if( rst_i )
          burstcount_o <= AMM_BURST_W'( 0 );
        else if( start_trans_stb )
          burstcount_o <= test_param_reg_i[0][AMM_BURST_W - 1 : 0];

      assign byteenable_o = BYTE_PER_WORD{ 1'b1 };

      always_ff @( posedge clk_i, posedge rst_i )
        if( rst_i )
          burst_cnt <= AMM_BURST_W'( 0 );
        else if( start_trans_stb )
          burst_cnt <= test_param_reg_i[0][AMM_BURST_W - 1 : 0];
        else if( write_complete_stb )
          burst_cnt <= burst_cnt - 1'b1;
    end
endgenerate

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    last_transaction_flg <= 1'b0;
  else if( start_trans_stb )
    last_transaction_flg <= ( !burst_en_flg );
  else if( write_o && !waitrequest_i )
    last_transaction_flg <= ( burst_cnt == 2 );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    write_o <= 1'b0;
  else if( start_trans_stb && !cur_op_type )
    write_o <= 1'b1;
  else if( last_transaction_flg && write_o && !waitrequest_i )
    write_o <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    read_o <= 1'b0;
  else if( start_trans_stb && cur_op_type )
    read_o <= 1'b1;
  else if( !waitrequest_i )
    read_o <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    rnd_data_reg <= 8'hFF;
  else if( test_param_reg_i[0][12] )
    if( start_trans_stb || ( write_o && !waitrequest_i ) )
      rnd_data_reg <= { rnd_data_reg[6:0], rnd_data_gen_bit };

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    writedata_o <= AMM_DATA_W'( 0 );
  else if( start_trans_stb || ( write_o && !waitrequest_i ) )
    if( test_param_reg_i[0][12] )
      writedata_o <= BYTE_PER_WORD{ rnd_data_reg };
    else
      writedata_o <= test_param_reg_i[1][7:0];

assign burst_en         = ( !operation_i.op_type && operation_i.low_burst && operation_i.high_burst );
assign current_burst_en = ( !current_operation.op_type && current_operation.low_burst && current_operation.high_burst );

assign start_transaction = ( operation_valid_i && !busy_o );
assign rnd_data_gen_bit  = ( rnd_data[6] ^ rnd_data[1] ^ rnd_data[0] );

assign write_complete_stb = ( write_o && !waitrequest_i );
assign start_trans_stb    = ( cmd_accept_ready_o && trans_pkt_en );

endmodule
