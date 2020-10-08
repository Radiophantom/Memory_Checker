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
          if( start_bit_en  == 1'b1 )
            next_state = START_TRANSACTION_S;
        end
      START_TRANSACTION_S : 
        begin
          case( csr[1][15:14] )
            2'b00 : next_state = WRITE_ONLY_S;
            2'b01 : next_state = READ_ONLY_S;
            2'b10 : next_state = WRITE_S;
          endcase
        end
      WRITE_ONLY_S :
        begin
          if( end_transaction && ( cmd_cnt == 0 ) )
            next_state = END_TRANSACTION_S;
        end
      READ_ONLY_S : 
        begin
          if( end_transaction && (cmd_cnt == 0 ) )
            next_state = END_TRANSACTION_S;
        end
      WRITE_S : 
        begin
          if( end_transaction && ( cmd_cnt == 0 ) )
            next_state = END_TRANSACTION_S;
          else
            next_state = READ_S;
        end
      READ_S : 
        begin
          next_state = WRITE_S;
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
    cmd_cnt <= '0;
  else if( start_bit_en )
    cmd_cnt <= csr[2];
  else if( end_transaction && ( cmd_cnt != 0 ) )
    cmd_cnt <= cmd_cnt - 1;

assign end_transaction = !waitrequest;
assign start_bit_en = ( csr[0][0] == 1'b1 );
assign compare_en = ( ( state == READ_S ) && readdatavalid );
assign repeat_en = ( state == WRITE_ONLY_S ) || ( state == READ_ONLY_S ) || ( state == WRITE_S );

endmodule
