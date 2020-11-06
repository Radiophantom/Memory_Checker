module ctrl_FSM
(
  input   rst_i,
  input   clk_i,

  input   start_test_i,
  
  input   cmd_accepted_i,

  input   data_check_valid_i,
  input   data_check_success_i,

  output  trans_en_o,
  output  trans_type_o, // 0-write, 1-read

  output  next_addr_en_o,
  output  check_data_en_o,

  output  save_dev_state_o,
  output  restore_dev_state_o,

  output  test_finished_o
);

typedef enum logic [2:0] { IDLE_S, START_TEST_S, WRITE_ONLY_S, READ_ONLY_S, WRITE_WORD_S, READ_WORD_S, CHECK_WORD_S, CHECK_ALL_WORDS_S, ERROR_CHECK_WORD_S, END_TRANSACTION_S } state, next_state;

logic [6:0] cmd_cnt;

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
          if( start_test_i == 1'b1 )
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
          if( last_transaction && cmd_accepted_i )
            next_state = END_TRANSACTION_S;
        end
      READ_ONLY_S :
        begin
          if( last_transaction && cmd_accepted_i )
            next_state = END_TRANSACTION_S;
        end
      WRITE_ONE_WORD_S :
        begin
          if( cmd_accepted_i )
            next_state = READ_ONE_WORD_S;
        end
      READ_ONE_WORD_S :
        begin
          if( cmd_accepted_i )
            next_state = CHECK_ONE_WORD_S;
        end
      CHECK_ONE_WORD_S :
        begin
          if( data_check_valid_i )
            if( !data_check_success_i )
              next_state = ERROR_CHECK_WORD_S;
            else if( last_transaction )
              next_state = END_TRANSACTION_S;
            else
              next_state = WRITE_ONE_WORD_S;
        end
      WRITE_ALL_WORDS_S :
        begin
          if( last_transaction && cmd_accepted )
            next_state = RESTORE_CHECKER_STATE_S;
        end
      RESTORE_CHECKER_STATE_S :
        begin
          next_state = CHECK_ALL_WORDS_S;
        end
      CHECK_ALL_WORDS_S :
        begin
          if( data_check_valid_i )
            if( !data_check_success_i )
              next_state = ERROR_CHECK_WORD_S;
            else if( last_transaction )
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
  if( rst_i  )
    cmd_cnt <= 0;
  else if( start_test_i || ( state == RESTORE_CHECKER_STATE_S ) )
    cmd_cnt <= csr[1][31:20];
  else if( cmd_accepted_i && ( cmd_cnt != 0 ) )
    cmd_cnt <= cmd_cnt - 1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    last_transaction <= 1'b0;
  else if( start_test_i || ( state == RESTORE_CHECKER_STATE_S ) )
    last_transaction <= ( csr[1][31:20] == 1 ); // check if no repeat cmd enable
  else if( ( cmd_cnt == 2 ) && cmd_accepted_i )
    last_transaction <= 1'b1;
  else if( cmd_accepted )
    last_transaction <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    save_dev_state_o <= 1'b0;
  else if( start_test_i && ( csr[1][17:16] == 2'b11 ) )
    save_dev_state_o <= 1'b1;
  else
    save_dev_state_o <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    restore_dev_state_o <= 1'b0;
  else if( state == RESTORE_CHECKER_STATE_S )
    restore_dev_state_o <= 1'b1;
  else
    restore_dev_state_o <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    check_data_en_o <= 1'b0;
  else if( ( state == READ_WORD_S ) && cmd_accepted_i )
    check_data_en_o <= 1'b1;
  else if( ( state == CHECK_ALL_WORDS_S ) && cmd_accepted_i )
    if( !last_transaction )
      check_data_en_o <= 1'b1;
    else
      check_data_en_o <= 1'b0;
  else if( cmd_accepted_i )
    check_data_en_o <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    trans_en_o <= 1'b0;
  else if( ( state == WRITE_ONLY_S ) || ( state == READ_ONLY_S ) || ( state == WRITE_ALL_WORDS_S ) || ( state == CHECK_ALL_WORDS_S ) )
    if( !last_transaction )
      trans_en_o <= 1'b1;
    else
      if( trans_en_o == 1'b1 && cmd_accepted_i )
        trans_en_o <= 1'b0;
      else
        trans_en_o <= 1'b1;
  else if( ( state == WRITE_ONE_WORD_S ) || ( state == READ_ONE_WORD_S )
    trans_en_o <= 1'b1;
  else if( state == CHECK_WORD_S )
    if( cmd_accepted_i )
      trans_en_o <= 1'b0;
  else
    trans_en_o <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    trans_type_o <= 1'b0;
  else if( ( state == WRITE_ONLY_S ) || ( state == WRITE_ALL_WORDS_S ) )
    trans_type_o <= 1'b0;
  else if( ( state == READ_ONLY_S ) || ( state == CHECK_ALL_WORDS_S ) )
    trans_type_o <= 1'b1;
  else if( state == WRITE_ONE_WORD_S )
    trans_type_o <= 1'b0;
  else if( state == READ_ONE_WORD_S )
    trans_type_o <= cmd_accepted_i;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    next_addr <= 1'b0;
  else if( start_test_i && ( csr[1][17:16] != 2'b10 ) )
    next_addr <= 1'b1;
  else if( state == WRITE_ONE_WORD_S )
    next_addr <= 1'b1;
  else if( state == READ_ONE_WORD_S ) || cmd_accepted_i )
    next_addr <= 1'b0;

// save status of the test and last or error address
always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    finished_reg_status <= 1'b0;
  else if( state == END_TRANSACTION_S )
    finished_reg_status <= 1'b1;
  else if( state == ERROR_CHECK_WORD_S )
    finished_reg_status <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    finished_addr <= '0;
  else if( ( state == END_TRANSACTION_S ) || ( state == ERROR_CHECK_WORD_S ) )
    finished_addr <= check_addr; 

endmodule
