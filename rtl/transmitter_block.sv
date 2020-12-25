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

  // Address block interface
  input                                  operation_valid_i,
  input  transaction_type                operation_i,
  
  output logic                           busy_o,

  // Avalon-MM output interface
  input                                  readdatavalid_i,
  input  logic   [AMM_DATA_W - 1 : 0]    readdata_i,
  input                                  waitrequest_i,

  output logic   [AMM_ADDR_W - 1 : 0]    address_o,
  output logic                           read_o,
  output logic                           write_o,
  output logic   [AMM_DATA_W - 1 : 0]    writedata_o,
  output logic   [AMM_BURST_W - 1 : 0]   burstcount_o,
  output logic   [BYTE_PER_WORD - 1 : 0] byteenable_o
);

function logic [BYTE_PER_WORD - 1 : 0] byteenable_ptrn( input logic                       start_offset_en,
                                                        input logic [BYTE_ADDR_W - 1 : 0] start_offset,
                                                        input logic                       end_offset_en,
                                                        input logic [BYTE_ADDR_W : 0]     end_offset      );
  for( int i = 0; i < BYTE_PER_WORD; i++ )
    case( {start_offset_en, end_offset_en} )
      2'b01   : byteenable_ptrn[i] = ( i < end_offset    );
      2'b10   : byteenable_ptrn[i] = ( i >= start_offset );
      2'b11   : byteenable_ptrn[i] = ( i >= start_offset ) && ( i < end_offset );
      default : byteenable_ptrn[i] = 1'b1;
    endcase
  return byteenable_ptrn;
endfunction

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    busy_o <= 1'b0;
  else if( !busy_o )
    if( operation_i.op_type )
      busy_o <= ( start_transaction && waitrequest_i );
    else
      busy_o <= ( start_transaction && ( burst_en || waitrequest_i );
  else if( current_burst_en && !current_operation.op_type )
    busy_o <= ( last_transaction && !waitrequest_i );
  else
    busy_o <= ( !waitrequest_i );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    current_operation <= '0;
  else if( start_transaction )
    current_operation <= operation_i;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    address_o <= '0;
  else if( start_transaction )
    address_o <= { address_i, (BYTE_ADDR_W)'b0 };

generate
  if( ADDR_TYPE == BYTE )
    begin
      always_ff @( posedge clk_i, posedge rst_i )
        if( rst_i )
          burstcount_o <= '0;
        else if( start_transaction )
          burstcount_o <= csr[1][AMM_BURST_W - 1 : 0];

      always_ff @( posedge clk_i, posedge rst_i )
        if( rst_i )
          byteenable_o <= '0;
        else if( start_transaction && operation_i.op_type )
          byteenable_o <= '1;
        else if( start_transaction || ( busy_o && !waitrequest_i ) )
          if( operation_i.op_type )
            byteenable_o <= '1;
          else if( burst_en )
            byteenable_o <= byteenable_ptrn( start_transaction, operation_i.start_offset, last_transaction, current_operation.end_offset );
          else
            byteenable_o <= byteenable_ptrn( 1'b1, operation_i.start_offset, 1'b1, operation_i.end_offset );
    end
  else if( ADDR_TYPE == WORD )
    begin
      always_ff @( posedge clk_i, posedge rst_i )
        if( rst_i )
          burstcount_o <= '0;
        else if( start_transaction )
          if( operation_i.op_type )
            burstcount_o <= operation_i.burst_word_count;
          else
            burstcount_o <= csr[1][AMM_BURST_W - 1 : 0];

      assign byteenable_o = (BYTE_PER_WORD)'b1;
    end
endgenerate

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    burst_cnt <= '0;
  else if( start_transaction )
    burst_cnt <= operation_i.burst_word_count;
  else if( busy_o && !waitrequest_i )
    burst_cnt <= burst_cnt - 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    last_transaction <= 1'b0;
  else if( busy_o && !waitrequest_i )
    last_transaction <= ( burst_cnt == 'd2 );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    write_o <= 1'b0;
  else if( start_transaction && ( operation_i.op_type == 1'b0 ) )
    write_o <= 1'b1;
  else if( current_burst_en )
    write_o <= !( busy_o && last_transaction && !waitrequest_i );
  else if( !waitrequest_i )
    write_o <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    read_o <= 1'b0;
  else if( start_transaction && ( operation_i.op_type == 1'b1 ) )
    read_o <= 1'b1;
  else if( !waitrequest_i )
    read_o <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    rnd_data_reg <= 8'hFF;
  else if( csr[1][12] == 1'b1 )
    if( start_transaction || ( busy_o && !waitrequest_i ) )
      rnd_data_reg <= { rnd_data_reg[6:0], rnd_data_gen_bit };

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    writedata_o <= '0;
  else if( start_transaction || ( busy_o && !waitrequest_i ) )
    if( csr[1][12] == 1'b0 )
      writedata_o <= csr[3][7:0];
    else
      writedata_o <= { (BYTE_PER_WORD){ rnd_data_reg } };

assign burst_en         = ( !operation_i.op_type && operation_i.low_burst && operation_i.high_burst );
assign current_burst_en = ( !current_operation.op_type && current_operation.low_burst && current_operation.high_burst );

assign start_transaction = ( operation_valid_i && !busy_o );
assign rnd_data_gen_bit  = ( rnd_data[6] ^ rnd_data[1] ^ rnd_data[0] );

endmodule
