import settings_pkg::*;

module transmitter_block ( 
  input                                 rst_i,
  input                                 clk_i,

  // Address block interface
  input                                 op_valid_i,
  input                                 op_type_i,
  input  trans_struct_type              op_pkt_struct_i,

  input         [0 : 1] [31 : 0]        test_param_reg_i,
  
  output logic                          cmd_accept_ready_o,
  output logic                          trans_block_busy_o, // ??? may be signal not need

  // Compare block interface
  input                                 error_check_i,

  output logic                          cmp_pkt_en_o,
  output pkt_struct_type                cmp_pkt_struct_o,

  // Avalon-MM output interface
  input                                 readdatavalid_i,
  input         [AMM_DATA_W - 1    : 0] readdata_i,
  input                                 waitrequest_i,

  output logic  [AMM_ADDR_W - 1    : 0] address_o,
  output logic                          read_o,
  output logic                          write_o,
  output logic  [AMM_DATA_W - 1    : 0] writedata_o,
  output logic  [AMM_BURST_W - 1   : 0] burstcount_o,
  output logic  [BYTE_PER_WORD - 1 : 0] byteenable_o
);

localparam int CMP_PKT_W = ( ADDR_W + AMM_BURST_W + 2*BYTE_PER_WORD + 9);

function logic [BYTE_PER_WORD - 1 : 0] byteenable_ptrn_func(  input logic                       start_or_end_flag, // 0-start, 1-end
                                                              input logic [BYTE_ADDR_W - 1 : 0] start_offset,
                                                              input logic [BYTE_ADDR_W - 1 : 0] end_offset        );
  for( int i = 0; i < BYTE_PER_WORD; i++ )
    if( start_or_end_flag )
      byteenable_ptrn[i] = ( i <= end_offset   );
    else
      byteenable_ptrn[i] = ( i >= start_offset );
endfunction

// csr registers casting
data_mode_type              data_ptrn_type_reg;
test_mode_type              test_type_reg;

logic [AMM_BURST_W - 1 : 0] burstcount_csr_reg;
logic [7 : 0]               fix_data_ptrn_reg;

assign fix_data_ptrn_reg  = test_param_reg_i[1][7 : 0];
assign burstcount_csr_reg = test_param_reg_i[0][AMM_BURST_W - 1 : 0];
assign data_ptrn_type_reg = test_param_reg_i[0][12];
assign test_type_reg      = test_param_reg_i[0][17 : 16];

// variables declaration
logic [AMM_BURST_W - 1 : 0] burst_cnt;
logic                       write_word_complete_stb;
logic                       start_trans_stb;
logic                       last_transaction_flg;
logic                       cur_op_type;
pkt_struct_type             cur_op_pkt_struct;
logic                       low_burst_en_flg;
logic                       high_burst_en_flg;
logic                       trans_pkt_en;

logic [BYTE_PER_WORD - 1 : 0] end_mask_temp;

// first stage -- analyzing of packet, calculating main expression
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
    high_burst_en_flg <= ( op_pkt_struct_i.high_burst_bits != 0 );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    low_burst_en_flg <= 1'b0;
  else if( cmd_accept_ready_o && op_valid_i )
    low_burst_en_flg <= ( op_pkt_struct_i.low_burst_bits >= BYTE_PER_WORD );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    cur_op_pkt_struct <= CMP_PKT_W'( 0 );
  else if( cmd_accept_ready_o && op_valid_i )
    begin
      cur_op_pkt_struct.word_address     <= op_pkt_struct_i.word_address;
      cur_op_pkt_struct.burst_word_count <= op_pkt_struct_i.high_burst_bits;
      cur_op_pkt_struct.start_mask       <= byteenable_ptrn_func( op_pkt_struct_i.start_offset, 0 );
      cur_op_pkt_struct.end_mask         <= byteenable_ptrn_func( op_pkt_struct_i.end_offset,   1 );
    end

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    cur_op_type <= 1'b0;
  else if( cmd_accept_ready_o && op_valid_i )
    cur_op_type <= op_type_i;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    end_mask_temp <= BYTE_PER_WORD'( 0 );
  else if( trans_pkt_en )
    end_mask_temp <= cur_op_pkt_struct.end_mask;

// second stage -- transmitting packet through AMM interface
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
    address_o <= AMM_ADDR_W'( cur_op_pkt_struct.word_address << BYTE_ADDR_W );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    last_transaction_flg <= 1'b0;
  else if( start_trans_stb )
    last_transaction_flg <= !( high_burst_en_flg || low_burst_en_flg );
  else if( write_cycle_complete_stb )
    last_transaction_flg <= ( burst_cnt == 2 );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    write_o <= 1'b0;
  else if( start_trans_stb && !cur_op_type )
    write_o <= 1'b1;
  else if( last_transaction_flg && write_cycle_complete_stb )
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
  else if( data_ptrn_type_reg == RND_DATA )
    if( start_trans_stb || write_cycle_complete_stb )
      rnd_data_reg <= { rnd_data_reg[6:0], rnd_data_gen_bit };

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    writedata_o <= AMM_DATA_W'( 0 );
  else if( start_trans_stb || write_cycle_complete_stb )
    if( data_ptrn_type_reg == RND_DATA )
      writedata_o <= BYTE_PER_WORD{ rnd_data_reg };
    else
      writedata_o <= fix_data_ptrn_reg;

// interaction with compare block
always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    cmp_pkt_en_o <= 1'b0;
  else if(  )
    cmp_pkt_en_o <= ( start_trans_stb && !cur_op_type );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    cmp_pkt_struct_o <= CMP_PKT_W'( 0 );
  else if( start_trans_stb && !cur_op_type )
    begin
      cmp_pkt_struct_o.word_address     <= cur_op_pkt_struct.word_address;
      cmp_pkt_struct_o.burst_word_count <= cur_op_pkt_struct.burst_word_count;
      cmp_pkt_struct_o.start_mask       <= cur_op_pkt_struct.start_mask;
      cmp_pkt_struct_o.end_mask         <= cur_op_pkt_struct.end_mask;
      cmp_pkt_struct_o.data_ptrn_type   <= data_ptrn_type_reg;
      if( data_ptrn_type_reg == RND_DATA )
        cmp_pkt_struct_o.data_ptrn <= rnd_data_reg;
      else
        cmp_pkt_struct_o.data_ptrn <= fix_data_ptrn_reg;
    end

generate
  if( ADDR_TYPE == BYTE )
    begin
//----------------------------------------------------------------------------------------------------
      logic [AMM_BURST_W - 1 : 0] burstcount_exp;

      always_ff @( posedge clk_i, posedge rst_i )
        if( rst_i )
          burstcount_o <= AMM_BURST_W'( 0 );
        else if( start_trans_stb )
          if( cur_op_type )
            burstcount_o <= burstcount_exp;
          else
            burstcount_o <= burstcount_csr_reg + 1'b1;

      always_ff @( posedge clk_i, posedge rst_i )
        if( rst_i )
          byteenable_o <= BYTE_PER_WORD'( 0 );
        else if( start_trans_stb )
          if( cur_op_type )
            byteenable_o <= BYTE_PER_WORD{ 1'b1 };
          else if( high_burst_en_flg || low_burst_en_flg )
            byteenable_o <= cur_op_pkt_struct.start_mask;
          else
            byteenable_o <= ( cur_op_pkt_struct.start_mask && cur_op_pkt_struct.end_mask );
        else if( write_cycle_complete_stb )
          byteenable_o <= byteenable_temp;

      always_ff @( posedge clk_i, posedge rst_i )
        if( rst_i )
          burst_cnt <= AMM_BURST_W'( 0 );
        else if( start_trans_stb )
          burst_cnt <= burstcount_exp;
        else if( write_cycle_complete_stb )
          burst_cnt <= burst_cnt - 1'b1;

      assign burstcount_exp = ( low_burst_en_flg ) ?  ( cur_op_pkt_struct.burst_word_count + 2'd2 ) :
                                                      ( cur_op_pkt_struct.burst_word_count + 2'd1 );

      assign byteenable_temp = ( burst_cnt == 2 ) ? ( end_mask_temp         ) :
                                                    ( BYTE_PER_WORD{ 1'b1 } );
//----------------------------------------------------------------------------------------------------
    end
  else if( ADDR_TYPE == WORD )
    begin
//----------------------------------------------------------------------------------------------------
      always_ff @( posedge clk_i, posedge rst_i )
        if( rst_i )
          burstcount_o <= AMM_BURST_W'( 0 );
        else if( start_trans_stb )
          burstcount_o <= burstcount_csr_reg;

      always_ff @( posedge clk_i, posedge rst_i )
        if( rst_i )
          burst_cnt <= AMM_BURST_W'( 0 );
        else if( start_trans_stb )
          burst_cnt <= burstcount_csr_reg;
        else if( write_cycle_complete_stb )
          burst_cnt <= burst_cnt - 1'b1;

      assign byteenable_o = BYTE_PER_WORD{ 1'b1 };
//----------------------------------------------------------------------------------------------------
    end
endgenerate

assign rnd_data_gen_bit         = ( rnd_data[6] ^ rnd_data[1] ^ rnd_data[0] );
assign write_cycle_complete_stb = ( write_o && !waitrequest_i               );
assign start_trans_stb          = ( cmd_accept_ready_o && trans_pkt_en      );

endmodule
