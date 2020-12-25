module transmitter_block #(
  parameter AMM_DATA_W    = 128,
  parameter AMM_ADDR_W    = 12,
  parameter AMM_BURST_W   = 11,
  parameter ADDR_TYPE     = BYTE,

  parameter BYTE_PER_WORD = AMM_DATA_W/8,
  parameter BYTE_ADDR_W   = $clog2( BYTE_PER_WORD ),
  parameter ADDR_W        = ( AMM_ADDR_W - BYTE_ADDR_W )
)( 
  input                                  rst_i,
  input                                  clk_i,

  // Output interface
  input                                  reset_module_i,

  output logic  [31:0] write_ticks_o,
  output logic  [31:0] write_unit_count_o,
  output logic  [31:0] read_ticks_o,
  output logic  [31:0] read_word_count_o,
  output logic  [15:0] min_delay_o,
  output logic  [15:0] max_delay_o,
  output logic  [31:0] sum_delay_o,
  output logic  [31:0] read_transaction_count_o,
  
  // Avalon-MM output interface
  input                         readdatavalid_i,
  input                         waitrequest_i,

  input                         read_i,
  input                         write_i,
  input [AMM_BURST_W - 1 : 0]   burstcount_i,
  input [BYTE_PER_WORD - 1 : 0] byteenable_i
);

automatic function logic [BYTE_ADDR_W : 0] byte_amount_func( input logic [BYTE_PER_WORD-1 : 0] byteenable_vec );
  //byte_amount_func = (BYTE_ADDR_W)'d0;
  foreach( byteenable_vec[i] )
    if( byteenable_vec[i] )
      byte_amount_func++;
  return byte_amount_func;
endfunction

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    write_unit_count_en <= 1'b0;
  else
    write_unit_count_en <= ( write_i && !waitrequest_i );

logic write_unit_count_en;
logic [11:0] write_unit_cnt_high, write_unit_cnt_low ;
logic high_unit_cnt_en;

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

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    read_sig_temp <= 1'b0;
  else if( read_i && !waitrequest_i )
    read_sig_temp <= 1'b0;
  else
    read_sig_temp <= read_i;

assign read_strobe = ( !read_sig_temp && read_i ); 

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    first_read_cnt <= (AMM_BURST_W)'d0;
  else if( read_strobe && !first_read_cnt_busy )
    first_read_cnt <= burstcount_i;
  else if( ( first_read_cnt != 0 ) && readdatavalid_i )
    first_read_cnt <= first_read_cnt - 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    first_read_cnt_busy <= 1'b0;
  else if( read_strobe && !first_read_cnt_busy )
    first_read_cnt_busy <= 1'b1;
  else if( last_first_cnt_word )
    first_read_cnt_busy <= 1'b0;

assign last_first_cnt_word = ( readdatavalid_i && ( first_read_cnt == 1 ) );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    second_read_cnt <= 0;
  else if( read_strobe && first_read_cnt_busy )
    second_read_cnt <= burstcount_i;
  else if( ( second_read_cnt != 0 ) && readdatavalid_i && !first_read_cnt_busy )
    second_read_cnt <= second_read_cnt - 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    second_read_cnt_busy <= 1'b0;
  else if( read_strobe && first_read_cnt_busy )
    second_read_cnt_busy <= 1'b1;
  else if( last_second_cnt_word )
    second_read_cnt_busy <= 1'b0;

assign last_second_cnt_word = ( readdatavalid_i && ( second_read_cnt == 1 ) );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    read_ticks_o <= 32'd0;
  else if( reset_module_i )
    read_ticks_o <= 32'd0;
  else if( first_read_cnt_busy || second_read_cnt_busy )
    read_ticks_o <= read_ticks_o + 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    read_word_count_o <= 32'd0;
  else if( reset_module_i )
    read_word_count_o <= 32'd0;
  else if( readdatavalid_i )
    read_word_count_o <= read_word_count_o + 1'b1;

endmodule
