module measure_block #(
  parameter int AMM_DATA_W    = 128,
  parameter int AMM_BURST_W   = 11,
  parameter int ADDR_TYPE     = BYTE,

  parameter int BYTE_PER_WORD = AMM_DATA_W/8,
  parameter int BYTE_ADDR_W   = $clog2( BYTE_PER_WORD )
)( 
  input                                 rst_i,
  input                                 clk_i,

  // Avalon-MM interface
  input                                 readdatavalid_i,
  input                                 waitrequest_i,

  input                                 read_i,
  input                                 write_i,
  input         [AMM_BURST_W - 1   : 0] burstcount_i,
  input         [BYTE_PER_WORD - 1 : 0] byteenable_i,

  // CSR interface
  input                                 reset_module_i,

  output logic                          busy_status_flag_o,

  output logic  [31:0]                  sum_delay_o,
  output logic  [15:0]                  min_delay_o,
  output logic  [15:0]                  max_delay_o,
  output logic  [31:0]                  read_transactions_count_o,
  output logic  [31:0]                  read_ticks_o,
  output logic  [31:0]                  read_words_count_o,

  output logic  [31:0]                  write_ticks_o,
  output logic  [31:0]                  write_units_count_o

  input                 [31 : 0]  read_trans_count_i,
  input                 [31 : 0]  min_max_delay_i,
  input                 [31 : 0]  sum_delay_i,

  input                 [31 : 0]  read_ticks_i,
  input                 [31 : 0]  read_words_count_i,

  input                 [31 : 0]  write_ticks_i,
  input                 [31 : 0]  write_units_count_i

  output logic                    start_test_o,
  output logic  [0 : 2] [31 : 0]  test_param_reg_o 
  
);

localparam CNT_NUM  = 4;
localparam CNT_W    = $clog2( CNT_NUM );

automatic function logic [BYTE_ADDR_W : 0] byte_amount_func( input logic [BYTE_PER_WORD-1 : 0] byteenable_vec );
  foreach( byteenable_vec[i] )
    if( byteenable_vec[i] )
      byte_amount_func++;
endfunction

assign read_strobe = ( read_i && !waitrequest_i ); 

logic unsigned [CNT_W-1 : 0] act_cnt_num, load_cnt_num;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    load_cnt_num <= CNT_W'( 0 );
  else if( read_strobe )
    load_cnt_num <= load_cnt_num + 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    act_cnt_num <= CNT_W'( 0 );
  else if( last_word_flag )
    act_cnt_num <= act_cnt_num + 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    word_cnt_vec = ( CNT_NUM * AMM_BURST_W )'( 0 );
  else
    for( int i = 0; i < ( CNT_NUM - 1 ); i++ )
      unique if( ( i == load_cnt_num ) && read_strobe )
        word_cnt_vec[i] <= burstcount_i;
      else if( ( i == act_cnt_num ) && readdatavalid_i )
        word_cnt_vec[i] <= word_cnt_vec[i] - 1'b1; 

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    last_word_vec <= CNT_NUM'( 0 );
  else
    for( int i = 0; i < ( CNT_NUM - 1 ); i++ )
      unique if( read_strobe && ( i == load_cnt_num ) )
        last_word_vec[i] <= ( burstcount_i == 1 );
      else if( readdatavalid_i && ( i == act_cnt_num ) )
        last_word_vec[i] <= ( word_cnt_vec[i] == 2 );

assign last_word_flag = last_word_vec[act_cnt_num] && readdatavalid_i;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    act_delay_cnt_vec <= CNT_NUM'( 0 );
  else
    for( int i = 0; i < ( CNT_NUM - 1 ); i++ )
      unique if( read_strobe && ( i == load_cnt_num ) )
        act_delay_cnt_vec[i] <= 1'b1;
      else( readdatavalid_i && ( i == act_cnt_num ) )
        act_delay_cnt_vec[i] <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    act_cnt_vec <= CNT_NUM'( 0 );
  else
    for( int i = 0; i < ( CNT_NUM - 1 ); i++ )
      unique if( read_strobe && ( i == load_cnt_num ) )
        act_cnt_vec[i] <= 1'b1;
      else( readdatavalid_i && ( i == act_cnt_num ) )
        act_cnt_vec[i] <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    delay_cnt_vec <= CNT_NUM'( 0 );
  else
    for( int i = 0; i < ( CNT_NUM - 1 ); i++ )
      if( act_delay_cnt_vec[i] )
        delay_cnt_vec[i] <= delay_cnt_vec[i] + 1'b1;
      else
        delay_cnt_vec[i] <= 32'd0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    prev_cnt_num <= CNT_W'( 0 );
  else if( last_word_flag )
    prev_cnt_num <= act_cnt_num;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    wr_delay_strobe <= 1'b0;
  else
    wr_delay_strobe <= last_word_flag;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    read_transactions_count_o <= 32'd0;
  else if( reset_module_i )
    read_transactions_count_o <= 32'd0;
  else if( wr_delay_strobe )
    read_transactions_count_o <= read_transactions_count_o + 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    read_words_count_o <= 32'd0;
  else if( reset_module_i )
    read_words_count_o <= 32'd0;
  else if( readdatavalid_i )
    read_words_count_o <= read_words_count_o + 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    min_delay_o <= 16'hFF_FF;
  else if( reset_module_i )
    min_delay_o <= 16'hFF_FF;
  else if( wr_delay_strobe && ( delay_cnt_vec[prev_cnt_num] < min_delay_o ) )
    min_delay_o <= delay_cnt_vec[prev_cnt_num];

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    max_delay_o <= 16'h0;
  else if( reset_module_i )
    max_delay_o <= 16'h0;
  else if( wr_delay_strobe && ( delay_cnt_vec[prev_cnt_num] > max_delay_o ) )
    max_delay_o <= delay_cnt_vec[prev_cnt_num];

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    sum_delay_o <= 32'd0;
  else if( reset_module_i )
    sum_delay_o <= 32'd0;
  else if( wr_delay_strobe )
    sum_delay_o <= sum_delay_o + delay_cnt_vec[prev_cnt_num];

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    read_ticks_cnt_o <= 32'd0;
  else if( reset_module_i )
    read_ticks_cnt_o <= 32'd0;
  else if( read_mode_active )
    read_ticks_cnt_o <= read_ticks_cnt_o + 1'b1;

assign read_mode_active = ( |act_delay_cnt_vec );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    write_ticks_o <= 32'd0;
  else if( reset_module_i )
    write_ticks_o <= 32'd0;
  else if( write_i )
    write_ticks_o <= write_ticks_o + 1'b1;

assign write_strobe = ( write_i && !waitrequest_i );

generate
  if( ADDR_TYPE == BYTE )
    logic [BYTE_ADDR_W : 0] byte_amount;
    logic                   delayed_wr_strobe;

    always_ff @( posedge clk_i, posedge rst_i )
      if( rst_i )
        byte_amount <= ( BYTE_ADDR_W + 1 )'( 0 );
      else if( reset_module_i )
        byte_amount <= ( BYTE_ADDR_W + 1 )'( 0 );
      else if( write_strobe )
        byte_amount <= byte_amount_func( byteenable_i );

    always_ff @( posedge clk_i, posedge rst_i )
      if( rst_i )
        delayed_wr_strobe <= 1'b0;
      else
        delayed_wr_strobe <= write_strobe;

    always_ff @( posedge clk_i, posedge rst_i )
      if( rst_i )
        write_units_count_o <= 32'd0;
      else if( reset_module_i )
        write_units_count_o <= 32'd0;
      else if( delayed_wr_strobe )
        write_units_count_o <= write_units_count_o + byte_amount;
  else if( ADDR_TYPE == WORD )
    always_ff @( posedge clk_i, posedge rst_i )
      if( rst_i )
        write_units_count_o <= 32'd0;
      else if( reset_module_i )
        write_units_count_o <= 32'd0;
      else if( write_strobe )
        write_units_count_o <= write_units_count_o + 1'b1;
endgenerate 

endmodule
