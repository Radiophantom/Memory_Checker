Module csr_block( 
  input                           rst_i,
  input                           clk_sys_i, // clk from ARM through AMM
  input                           clk_mem_i, // clk from hardware memory controller

  // Avalon-MM interface

  input                           read_i,   // 0 cycle delay to readdata | read_i     -> _/TTT\_
  input                           write_i,  //                           | readdata_o -> ______/TTT\_
  input                 [3  : 0]  address_i,
  input                 [31 : 0]  writedata_i,

  output  logic         [31 : 0]  readdata_o,

  // Output interface
  input                           write_result_i, 

  input                           test_result_i,
  input                 [31 : 0]  error_address_i,
  input                 [31 : 0]  error_data_i,

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

logic [2:0]         write_result_sync_reg;
logic               write_result_strobe;
logic [2:0]         reset_start_test_sync_reg;
logic               reset_start_bit;
logic [2:0]         start_test_sync_reg;

logic        [31:0] end_test_reg;
logic [0:9]  [31:0] result_csr_array;
logic [0:3]  [31:0] test_param_reg;
logic [0:14] [31:0] csr_array;

always_ff @( posedge clk_sys_i, posedge rst_i )
  if( rst_i )
    write_result_sync_reg <= 3'd0;
  else
    write_result_sync_reg <= { write_result_sync_reg[1:0], write_result_i };

always_ff @( posedge clk_sys_i, posedge rst_i )
  if( rst_i )
    end_test_reg[0] <= 1'b0;
  else if( write_result_strobe )
    end_test_reg[0] <= 1'b1;
  else if( read_i && ( address_i == 4 ) )
    end_test_reg[0] <= 1'b0;

always_ff @( posedge clk_sys_i, posedge rst_i )
  if( rst_i )
    result_csr_array <= (10*32)'( 0 ); // 10 register 32-bit
  else if( write_result_strobe )
    result_csr_array[0] <= test_result_i;
    result_csr_array[1] <= error_address_i;
    result_csr_array[2] <= error_data_i;
    result_csr_array[3] <= write_ticks_i;
    result_csr_array[4] <= write_units_count_i;
    result_csr_array[5] <= read_ticks_i;
    result_csr_array[6] <= read_words_count_i;
    result_csr_array[7] <= min_max_delay_i;
    result_csr_array[8] <= sum_delay_i;
    result_csr_array[9] <= read_trans_count_i;
    
always_ff @( posedge clk_sys_i, posedge rst_i )
  if( rst_i )
    test_param_reg <= (4*32)'( 0 );
  else
    if( address_i == 0 )
      begin
        if( reset_start_bit )
          test_param_reg[0][0] <= 1'b0;
        else if( write_i )
          test_param_reg[0][0] <= writedata_i[0];
      end
    else if( address_i <= 3 ) // really need this condition?
      if( write_i )
        test_param_reg[address_i] <= writedata_i;

always_ff @( posedge clk_mem_i, posedge rst_i )
  if( rst_i )
    start_test_sync_reg <= 3'd0;
  else
    start_test_sync_reg <= { start_test_sync_reg[1:0], test_param_reg[0][0] };

always_ff @( posedge clk_sys_i, posedge rst_i )
  if( rst_i )
    reset_start_test_sync_reg <= 3'd0;
  else
    reset_start_test_sync_reg <= { reset_start_test_sync_reg[1:0], start_test_sync_reg[1] };

always_ff @( posedge clk_sys_i, posedge rst_i )
  if( rst_i )
    readdata_o <= 32'( 0 );
  else if( read_i )
    readdata_o <= csr_array[address_i];

assign write_result_strobe  = ( write_result_sync_reg[1]      && !write_result_sync_reg[2]      );
assign start_test_o         = ( start_test_sync_reg[1]        && !start_test_sync_reg[2]        );
assign reset_start_bit      = ( reset_start_test_sync_reg[1]  && !reset_start_test_sync_reg[2]  );
assign csr_array            = { test_param_reg, end_test_reg, result_csr_array };
assign test_param_reg_o     = test_param_reg[1:3];

endmodule csr_block
