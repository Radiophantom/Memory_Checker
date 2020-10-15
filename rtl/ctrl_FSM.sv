module ctrl_FSM #(

)(

);

typedef enum logic [2:0] { IDLE_S, START_TRANSACTION_S, } state, next_state;

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
          case( csr[1][15:14] )
            2'b00 : next_state = WRITE_ONLY_S;
            2'b01 : next_state = READ_ONLY_S;
            2'b10 : next_state = WRITE_WORD_S;
            2'b11 : next_state = WRITE_ONLY_S;
          endcase
        end
      WRITE_ONLY_S :
        begin
          if( cmd_cnt == 0 )
            if( csr[1][15:14] == 2'b11 )
              next_state = READ_ONLY_S;
            else
              next_state = END_TRANSACTION_S;
        end
      READ_ONLY_S :
        begin
          if( csr[1][15:14] == 2'b11 )
            if( word_checked_sig && !correct_data_sig )
              next_state = CHECK_DATA_FAILED_S;
            else if( cmd_cnt == 0 )
              next_state = END_TRANSACTION_S;
          else if( cmd_cnt == 0 )
           next_state = END_TRANSACTION_S;
        end
      WRITE_WORD_S :
        begin
          if( cmd_accepted )
            next_state = READ_WORD_S;
        end
      READ_WORD_S :
        begin
          if( cmd_accepted )
            next_state = CHECK_WORD_S;
        end
      CHECK_WORD_S :
        begin
          if( word_checked_sig )
            if( !correct_data_sig )
              next_state = CHECK_DATA_FAILED_S;
            else if( cmd_cnt != 0 )
              next_state = WRITE_WORD_S;
            else
              next_state = END_TRANSACTION_S;
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
    cmp_en <= 1'b0;
  else if( ( state == READ_WORD_S ) && cmd_block_ready )
    cmp_en <= 1'b1;
  else if( ( state == READ_ONLY_S ) && ( csr[1][15:14] == 2'b11 ) )
    cmp_en <= 1'b1;
  else if( word_checked_sig )
    cmp_en <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    restore_and_check <= 1'b0;
  else if( ( state == WRITE_ONLY_S ) && ( cmd_cnt == 0 ) )
    restore_and_check <= ( csr[1][15:14] == 2'b11 );
  else
    restore_and_check <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i  )
    cmd_cnt <= 0;
  else if( start_bit_set || ( restore_and_check == 1'b1 ) )
    cmd_cnt <= csr[1][8:0];
  else if( cmd_block_ready && ( cmd_cnt != 0 ) )
    cmd_cnt <= cmd_cnt - 1;

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


always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    start_bit_sync_reg <= '0;
  else
    start_bit_sync_reg <= { start_bit_sync_reg[1:0], csr[0][0] };

assign start_bit_set = ( start_bit_sync_reg[2] == 1'b0 ) && ( start_bit_sync_reg[1] == 1'b1 );
assign cmp_data_en = ( state == READ_ONLY_S ) && ( !restore_and_check_sig ) && ( csr[1][15:14] == 2'b11 );

endmodule
