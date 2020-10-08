module address_block #(
  parameter DATA_DDR_W = 64,
  parameter DATA_AMM_W = 512
  parameter ADDR_TYPE = BYTE
)( input clk_i, 
  input rst_i,

  input start_transaction_en,
  input repeat_transaction_en,



  output
  output
);

localparam SYMBOL_PER_WORD = DATA_AMM_W/DATA_DDR_W;

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
      3'b010 : addr_reg <= 
      3'b011 : addr_reg <= 'd0;
      3'b100 : addr_reg <= addr_reg + 1;
    endcase

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    rnd_addr_reg <= (ADDR_W-1)'hFF_FF_FF_FF;
  else if( load_addr_ptrn )
    rnd_addr_reg <= load_rnd_addr;
  else if( rnd_addr_en )
    rnd_addr_reg <= { rnd_addr_reg[30:0], rnd_addr_gen_bit };

assign rnd_addr_gen_bit = rnd_addr[31] ^ rnd_addr[3] ^ rnd_addr[0];

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    save_rnd_addr <= '0;
  else if( start_bit && ( csr[1][15:14] == 2'b10 ) )
    save_rnd_addr <= rnd_addr;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    rnd_data <= 8'hFF;
  else if( load_data_ptrn )
    rnd_data <= load_rnd_data;
  else if( rnd_data_en )
    rnd_data <= { rnd_data[6:0], rnd_data_gen_bit };

assign rnd_data_gen_bit = rnd_data[6] ^ rnd_data[1] ^ rnd_data[0];

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    save_rnd_data <= '0;
  else if( start_bit && ( csr[1][15:14] == 2'b10 ) )
    save_rnd_data <= rnd_addr;

always_ff @( posedge clk_i, posedge rst_i )
  if( ADDR_TYPE = WORD )
      byteenable <= '1;
    else if( ADDR_TYPE = BYTE )
      if( ( csr[1][13:11] == 3'b010 ) || ( csr[1][13:11] == 3'b011 ) )
        for( int i = 0; i < DATA_BYTE; i++ )
          byteenable[i] = ( reg_addr == i );
      else if( burst_cnt > SYMBOL_PER_WORD )
        byteenable <= '1;
      else if( burst_cnt < SYMBOL_PER_WORD )
        for( int i = 0; i < SYMBOL_PER_WORD; i++ )
          if( i < reg_addr[2:0] )
            byteenable <= 1'b1;
          else
            byteenable <= 1'b0;



endmodule
