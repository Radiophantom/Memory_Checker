module ctrl_FSM #(
  
)(
  input clk_i,
  input rst_i,

  input 

  output 
);

typedef enum logic [2:0] { IDLE_S, START_TEST_S, WRITE_ONLY_S, READ_ONLY_S, WRITE_WORD_S, READ_WORD_S, CHECK_WORD_S, END_TRANSACTION_S } state, next_state;

logic [6:0] cmd_cnt;
logic start_tr_en, compare_en, ;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    state <= IDLE_S;
  else
    state <= next_state;

always_comb
  begin
    next_state = state;
    case( state )
      IDLE_S :
        begin
          if( start_bit_set == 1'b1 )
            next_state = START_TEST_S;
        end
      START_TEST_S :
        begin
          case( csr[1][17:16] )
            2'b00 : next_state = WRITE_ONLY_S;
            2'b01 : next_state = READ_ONLY_S;
            2'b10 : next_state = WRITE_ONE_WORD_S;
            2'b11 : next_state = WRITE_ALL_WORDS_S;
          endcase
        end
      WRITE_ONLY_S :
        begin
          if( cmd_cnt_empty && cmd_accepted )
            next_state = END_TRANSACTION_S;
        end
      READ_ONLY_S :
        begin
          if( cmd_cnt_empty && cmd_accepted )
            next_state = END_TRANSACTION_S;
        end
      WRITE_ONE_WORD_S :
        begin
          if( cmd_accepted )
            next_state = READ_ONE_WORD_S;
        end
      READ_ONE_WORD_S :
        begin
          if( cmd_accepted )
            next_state = CHECK_ONE_WORD_S;
        end
      CHECK_ONE_WORD_S :
        begin
          if( word_checked_sig )
            if( !correct_data_sig )
              next_state = ERROR_CHECK_WORD_S;
            else if( cmd_cnt_empty )
              next_state = END_TRANSACTION_S;
            else
              next_state = WRITE_ONE_WORD_S;
        end
      WRITE_ALL_WORDS_S :
        begin
          if( cmd_cnt_empty && cmd_accepted )
            next_state = RESTORE_CHECKER_STATE_S;
        end
      RESTORE_CHECKER_STATE_S :
        begin
          next_state = CHECK_ALL_WORDS_S;
        end
      CHECK_ALL_WORDS_S :
        begin
          if( word_checked_sig )
            if( !correct_data_sig )
              next_state = ERROR_CHECK_WORD_S;
            else if( cmd_cnt_empty )
              next_state = END_TRANSACTION_S;
        end
      ERROR_CHECK_WORD_S :
        begin
          next_state = IDLE_S;
        end
      END_TRANSACTION_S :
        begin
          next_state = IDLE_S;
        end
      default :
        begin
          next_state = IDLE_S;
        end
    endcase
  end

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    int_cmd_cnt <= '0;
  else if( ( csr[1][15:13] == 3'b010 ) || ( csr[1][15:13] == 3'b011 ) )
    if( state == START_TEST_S )
      int_cmd_cnt <= ADDR_W;
    else if( cmd_accepted )
      if( int_cmd_cnt != 0 )
        int_cmd_cnt <= int_cmd_cnt - 1;
      else
        int_cmd_cnt <= ADDR_W;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    int_cmd_cnt_empty <= 1'b0;
  else if( ( csr[1][15:13] != 3'b010 ) && ( csr[1][15:13] != 3'b011 ) )
    if( state == START_TEST_S )
      begin
        int_cmd_cnt_empty <= 1'b1;
      end
  else
    if( state == START_TEST_S )
      begin
        int_cmd_cnt_empty <= 1'b0;
      end
    else if( ( int_cmd_cnt == 1 ) && cmd_accepted )
      int_cmd_empty <= 1'b1;
    else
      int_cmd_empty <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    save_checker_state <= 1'b0;
  else



always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    cmp_en <= 1'b0;
  else if( ( state == READ_WORD_S ) && cmd_block_ready )
    cmp_en <= 1'b1;
  else if( ( state == READ_ONLY_S ) && ( csr[1][15:14] == 2'b11 ) )
    cmp_en <= 1'b1;
  else if( word_checked_sig )
    cmp_en <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i  )
    cmd_cnt <= 0;
  else if( start_bit_set || ( state == RESTORE_CHECKER_STATE_S ) )
    cmd_cnt <= csr[1][31:20];
  else if( cmd_accepted && ( cmd_cnt != 0 ) && int_cmd_empty )
    cmd_cnt <= cmd_cnt - 1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    cmd_cnt_empty <= '0;
  else if(



  
always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    wr_en <= 1'b0;
  else if( state == WRITE_ONLY_S )
    if( cmd_cnt > 1 )
      wr_en <= 1'b1;
    else if( cmd_cnt == 1 )
      if( wr_en == 1'b1 && cmd_block_ready )
        wr_en <= 1'b0;
      else
        wr_en <= 1'b1;
    else
      wr_en <= 1'b0;
  else if( state == WRITE_WORD_S )
    wr_en <= 1'b1;
  else if( state == READ_WORD_S )
    begin
      if( cmd_block_ready )
        wr_en <= 1'b0;
    end
  else
    wr_en <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    rd_en <= 1'b0;
  else if( state == READ_ONLY_S )
    if( cmd_cnt > 1 )
      rd_en <= 1'b1;
    else if( cmd_cnt == 1 )
      if( rd_en == 1'b1 && cmd_block_ready )
        rd_en <= 1'b0;
      else
        rd_en <= 1'b1;
    else
      rd_en <= 1'b0;
  else if( state == READ_WORD_S )
    rd_en <= cmd_block_ready;
  else if( state == CHECK_WORD_S )
    begin
      if( cmd_accept_ready )
        rd_en <= 1'b0;
    end
  else

assign cmp_data_en = ( state == READ_ONLY_S ) && ( !restore_and_check_sig ) && ( csr[1][15:14] == 2'b11 );

// detect start-test bit set and reset start-test bit in csr after it
always_ff @( posedge clk_2_i, posedge rst_i )
  if( rst_i )
    start_bit_sync_reg <= '0;
  else
    start_bit_sync_reg <= { start_bit_sync_reg[1:0], csr[0][0] };

always_ff @( posedge clk_1_i, posedge rst_i )
  if( rst_i )
    rst_start_bit_sync_reg <= '0;
  else
    rst_start_bit_sync_reg <= { rst_start_bit_sync_reg[1:0], start_bit_sync_reg[1] };

assign start_bit_set = ( start_bit_sync_reg[2] == 1'b0     ) && ( start_bit_sync_reg[1] == 1'b1     );
assign rst_start_bit = ( rst_start_bit_sync_reg[2] == 1'b0 ) && ( rst_start_bit_sync_reg[1] == 1'b1 );

endmodule
