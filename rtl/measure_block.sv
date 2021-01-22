module transmitter_block #(
  parameter AMM_DATA_W    = 128,
  parameter AMM_BURST_W   = 11,
  parameter ADDR_TYPE     = BYTE,

  parameter BYTE_PER_WORD = AMM_DATA_W/8,
  parameter BYTE_ADDR_W   = $clog2( BYTE_PER_WORD )
)( 
  input                                  rst_i,
  input                                  clk_i,

  // Output interface
  input                                  reset_module_i,

  output logic  [31:0] read_request_amount_o,
  output logic  [31:0] read_word_count_o,
  output logic  [15:0] min_delay_o,
  output logic  [15:0] max_delay_o,
  output logic  [31:0] sum_delay_o,
  output logic  [31:0] read_transaction_count_o,
  output logic  [31:0] write_ticks_o,
  output logic  [31:0] write_unit_count_o,
  
  // Avalon-MM output interface
  input                         readdatavalid_i,
  input                         waitrequest_i,

  input                         read_i,
  input                         write_i,
  input [AMM_BURST_W - 1 : 0]   burstcount_i,
  input [BYTE_PER_WORD - 1 : 0] byteenable_i
);

localparam CNT_NUM  = 4;
localparam CNT_W    = $clog2( CNT_NUM );

automatic function logic [BYTE_ADDR_W : 0] byte_amount_func( input logic [BYTE_PER_WORD-1 : 0] byteenable_vec );
  //byte_amount_func = (BYTE_ADDR_W)'d0;
  foreach( byteenable_vec[i] )
    if( byteenable_vec[i] )
      byte_amount_func++;
  return byte_amount_func;
endfunction

logic write_unit_count_en;
logic [11:0] write_unit_cnt_high, write_unit_cnt_low ;
logic high_unit_cnt_en;

assign read_strobe = ( read_i && !waitrequest_i ); 

logic unsigned [CNT_W-1 : 0] active_cnt_num, load_cnt_num;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    active_cnt_num <= (CNT_W)'d0;
  else if( last_word_flag ) 
    active_cnt_num <= active_cnt_num + 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    load_cnt_num <= (CNT_W)'d0;
  else if( read_strobe )
    load_cnt_num <= load_cnt_num + 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    word_cnt_vec = (CNT_NUM){ (AMM_BURST_W)'d0 };
  else
    for( int i = 0; i < (CNT_NUM-1); i++ )
      unique if( read_strobe && ( i == load_cnt_num ) )
        word_cnt_vec[i] <= burstcount_i;
      else if( readdatavalid_i && ( i == active_cnt_num ) )
        word_cnt_vec[i] <= word_cnt_vec[i] - 1'b1; 

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    last_word_vec <= (CNT_NUM){ 1'b0 };
  else
    for( int i = 0; i < (CNT_NUM-1); i++ )
      unique if( read_strobe && ( i == load_cnt_num ) )
        last_word_vec[i] <= ( burstcount_i == 1 );
      else if( readdatavalid_i && ( i == active_cnt_num ) )
        last_word_vec[i] <= ( burstcount_i == 2 );

assign last_word_flag = last_word_vec[active_cnt_num] && readdatavalid_i;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    act_cnt_vec <= (CNT_NUM){ 1'b0 };
  else
    for( int i = 0; i < (CNT_NUM-1); i++ )
      unique if( read_strobe && ( i == load_cnt_num ) )
        act_cnt_vec[i] <= 1'b1;
      else( readdatavalid_i && ( i == active_cnt_num ) )
        act_cnt_vec[i] <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    delay_cnt_vec <= (CNT_NUM){ 16'd0 };
  else
    for( int i = 0; i < CNT_NUM-1; i++ )
      if( act_cnt_vec[i] )
        delay_cnt_vec[i] <= delay_cnt_vec[i] + 1'b1;
      else
        delay_cnt_vec[i] <= 16'd0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    prev_cnt_num <= (CNT_W)'d0;
  else if( last_word_flag )
    prev_cnt_num <= active_cnt_num;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    wr_delay_strobe <= 1'b0;
  else
    wr_delay_strobe <= last_word_flag;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    read_request_amount_o <= (32)'d0;
  else if( reset_module_i )
    read_request_amount_o <= (32)'d0;
  else if( wr_delay_strobe )
    read_request_amount_o <= read_request_amount_o + 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    read_word_count_o <= 32'd0;
  else if( reset_module_i )
    read_word_count_o <= 32'd0;
  else if( readdatavalid_i )
    read_word_count_o <= read_word_count_o + 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    min_delay_o <= 16'b1; // 16'hFF_FF;
  else if( reset_module_i )
    min_delay_o <= 16'b1;
  else if( wr_delay_strobe && ( delay_cnt_vec[prev_cnt_num] < min_delay_o ) )
    min_delay_o <= delay_cnt_vec[prev_cnt_num];

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    max_delay_o <= 16'b0; // 16'd0;
  else if( reset_module_i )
    max_delay_o <= 16'b0;
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

assign read_mode_active = ( |act_cnt_vec );

















always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    write_unit_count_en <= 1'b0;
  else
    write_unit_count_en <= ( write_i && !waitrequest_i );


/*
generate
  if( ADDR_TYPE == BYTE )
    logic [BYTE_ADDR_W : 0] byte_amount;

    always_ff @( posedge clk_i, posedge rst_i )
      if( rst_i )
        byte_amount <= (BYTE_ADDR_W)'d0;
      else if( reset_module_i )
        byte_amount <= (BYTE_ADDR_W)'d0;
      else if( write_i && !waitrequest_i )
        byte_amount <= byte_amount_func( byteenable_i );

    always_ff @( posedge clk_i, posedge rst_i )
      if( rst_i )
        write_unit_cnt_low <= 12'd0;
      else if( reset_module_i )
        write_unit_cnt_low <= 12'd0;
      else if( write_unit_count_en )
        write_unit_cnt_low <= write_unit_cnt_low + byte_amount;

    assign write_unit_cnt_low_strobe =  ( write_unit_count_low + byte_amount ) >= (2**12) );
    //assign write_unit_cnt_low_strobe =  ( &write_unit_count_low[11:BYTE_ADDR_W-1] ) && 
    //                                    ( ( write_unit_count_low[BYTE_ADDR_W:0] + byte_amount ) >= 2**(BYTE_ADDR_W+1) );
  else if( ADDR_TYPE == WORD )
    always_ff @( posedge clk_i, posedge rst_i )
      if( rst_i )
        write_unit_cnt_low <= 12'd0;
      else if( reset_module_i )
        write_unit_cnt_low <= 12'd0;
      else if( write_unit_count_en )
        write_unit_cnt_low <= write_unit_cnt_low + 1'b1;

    assign write_unit_cnt_low_strobe =  ( write_unit_count_low == (2**12 - 1) );
endgenerate 

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    write_unit_cnt_low_strobe_reg <= 1'b0;
  else
    write_unit_cnt_low_strobe_reg <= ( write_unit_cnt_low_strobe && write_unit_count_en );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    write_unit_cnt_high <= 12'd0;
  else if( reset_module_i )
    write_unit_cnt_high <= 12'd0;
  else if( write_unit_cnt_low_strobe_reg )
    write_unit_cnt_high <= write_unit_cnt_high + 1'b1;

assign write_unit_count_o = { write_unit_cnt_high, write_unit_cnt_low };
*/

generate
  if( ADDR_TYPE == BYTE )
    logic [BYTE_ADDR_W : 0] byte_amount;

    always_ff @( posedge clk_i, posedge rst_i )
      if( rst_i )
        byte_amount <= (BYTE_ADDR_W)'d0;
      else if( reset_module_i )
        byte_amount <= (BYTE_ADDR_W)'d0;
      else if( write_i && !waitrequest_i )
        byte_amount <= byte_amount_func( byteenable_i );

    always_ff @( posedge clk_i, posedge rst_i )
      if( rst_i )
        write_unit_count_o <= 24'd0;
      else if( reset_module_i )
        write_unit_count_o <= 24'd0;
      else if( write_unit_count_en )
        write_unit_count_o <= write_unit_count_o + byte_amount;
  else if( ADDR_TYPE == WORD )
    always_ff @( posedge clk_i, posedge rst_i )
      if( rst_i )
        write_unit_count_o <= 24'd0;
      else if( reset_module_i )
        write_unit_count_o <= 24'd0;
      else if( write_unit_count_en )
        write_unit_count_o <= write_unit_count_o + 1'b1;
endgenerate 

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    write_ticks_o <= 32'd0;
  else if( reset_module_i )
    write_ticks_o <= 32'd0;
  else if( write_tick_en )
    write_ticks_o <= write_ticks_o + 1'b1;

endmodule
