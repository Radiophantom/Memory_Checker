module address_block #(
  parameter 
  parameter
)(
  input clk_i, 
  input rst_i,

  input start_transaction_en,
  input repeat_transaction_en,



  output
  output
);


logic [ADDR_W - 1:0] addr_reg;
logic [ADDR_W - 1:0] rnd_addr_reg;
logic 

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    addr_reg <= 'd0;
  else if( start_bit_en )
    case( csr[1][13:11] )
      3'b000 : addr_reg <= csr[3];
      3'b001 : addr_reg <= rnd_addr_reg;
      3'b010 : addr_reg <= 'd254;
      3'b011 : addr_reg <= 'd1;
      3'b100 : addr_reg <= csr[3];
    endcase
  else if( repeat_en )
    case( csr[1][13:11] )
      3'b001 : addr_reg <= rnd_addr_reg;
      3'b010 : 
      3'b011 : 
      3'b100 : addr_reg <= addr_reg + 1;
    endcase

always_ff @( posedge clk_i, posedge rst_i )
  if( rst

endmodule
