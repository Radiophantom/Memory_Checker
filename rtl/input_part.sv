module memory_checker #(
  parameter REG_AMOUNT = 10,
  parameter REG_W      = $clog2( REG_AMOUNT ),
  parameter CSR_W      = 32,
  parameter ADDR_W     = 16
)(
  input                      clk_i,
  input                      rst_i,

  input        [3 : 0]       address_slave,

  input                      write_slave,
  input        [CSR_W-1 : 0] writedata_slave,

  input                      read_slave,
  output logic               readdatavalid_slave,
  output logic [CSR_W-1 : 0] readdata_slave,

  input        [3 : 0]       burstcount_slave,

//----------------------------------------------------
  /*input                        write_master,
  input                        read_master,
  input        [ADDR_W-1 : 0]  address_master,
  input        [DATA_W-1 : 0]  writedata_master,
  output logic [DATA_W-1:0]    readdata_master,
  output logic                 readdatavalid_master,

  input        [BURST_W-1 : 0] burstcount_master*/
);

logic [CSR_W-1 : 0] ctrl_start_reg;
logic [CSR_W-1 : 0] ctrl_reg [4 : 0];
logic [CSR_W-1 : 0] stat_finish_reg;
logic [CSR_W-1 : 0] stat_reg [4 : 0];
logic [CSR_W-1 : 0] reg_in_model  [REG_W-1 : 0];
logic [CSR_W-1 : 0] reg_out_model [REG_W-1 : 0];

logic [15 : 0] reg_addr;
logic [15 : 0] data;
logic          wr_en;
logic          read_en;
logic          burst_type;

logic [2 : 0]  burst_cnt;

logic [7:0]    rnd_data      = 8'hFF;
logic [7:0]    save_rnd_data = 8'hFF;
logic [31:0]   rnd_addr      = ( ADDR_W )'hFF_FF_FF_FF;
logic [31:0]   save_rnd_addr = ( ADDR_W )'hFF_FF_FF_FF;

//-----------------------------------------------

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    wr_en <= 1'b0;
  else
    wr_en <= write_slave;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    wr_data <= '0;
  else if( write_slave )
    wr_data <= writedata_slave;

//-----------------------------------------------

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    rd_en <= 1'b0;
  else if( burst_en && burst_type )
    rd_en <= 1'b1;
  else
    rd_en <= read_slave;

always_comb
  if( burst_en )
    wr_allowed = ( reg_addr <= 4 );
  else
    wr_allowed = ( address_slave <= 4 );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    burst_type <= 1'b0;
  else if( !burst_en )
    if( write_slave )
      burst_type <= 1'b0;
    else if( read_slave )
      burst_type <= 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    burst_en <= 1'b0;
  else if( burst_en )
    if( burst_type )
      if( burst_cnt == 1 )
        burst_en <= 1'b0;
    else
      if( ( burst_cnt == 1 ) && wr_en )
        burst_en <= 1'b0;
  else if( ( write_slave || read_slave ) && ( burstcount_slave > 1 ) )
    burst_en <= 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    burst_cnt <= '0;
  else if( burst_en && ( burst_cnt != 0 ) )
    if( burst_type )
      burst_cnt <= burst_cnt - 1'b1;
    else if( wr_en )
      burst_cnt <= burst_cnt - 1'b1;
  else if( ( write_slave || read_slave ) && ( burstcount_slave > 1 ) )
    burst_cnt <= burstcount_slave;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    readdatavalid_slave <= 0;
  else
    readdatavalid_slave <= ( burst_type && burst_en ) || read_en;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    reg_addr <= '0;
  else if( burst_en )
    reg_addr <= reg_addr + 1'b1;
  else if( write_slave || read_slave )
    reg_addr <= address_slave;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    ctrl_reg <= '0;
  else if( wr_en && wr_allowed )
    ctrl_reg[reg_addr] <= wr_data;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )

  else



always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    rst_start_bit <= 1'b0;
  else
    rst_start_bit <= {rst_start_bit[0], 

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    readdata_slave <= '0;
  else if( burst_en || read_en )
    if( reg_addr != 5 )
      readdata_slave <= reg_model[reg_addr];
    else
      readdata_slave <= sync_finish_reg[1];

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    test_finished_reg <= '0;
  else
    test_finished_reg <= { test_finished_reg[0], test_finished };

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    sync_finish_reg <= '0;
  else
    sync_finish_reg <= { sync_finish_reg[0], stat_reg[0] };

assign reg_in_model  = { ctrl_reg, sync_finish_reg, stat_reg[4:1] }; // отображение регистра с учетом синхронизации на вход
assign reg_out_model = { sync_start_reg, ctrl_reg[4:1], stat_reg };  // отображение регистра с учетом синхронизации на выход

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
  if( rst_i )
    rnd_addr <= (ADDR_W-1)'hFF_FF_FF_FF;
  else if( load_addr_ptrn )
    rnd_addr <= load_rnd_addr;
  else if( rnd_addr_en )
    rnd_addr <= { rnd_addr[30:0], rnd_addr_gen_bit };

assign rnd_addr_gen_bit = rnd_addr[31] ^ rnd_addr[3] ^ rnd_addr[0];

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    save_rnd_addr <= '0;
  else if( start_bit && ( csr[1][15:14] == 2'b10 ) )
    save_rnd_addr <= rnd_addr;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    state <= IDLE_S;
  else
    state <= next_state;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    burst_cnt_reg <= '0;
  else if( start_transaction_en )
    if( csr[0] [15] == 1'b1 )
      burst_cnt_reg <= csr[2];
    else
      burst_cnt_reg <= 15'd1;

always_comb
  case( state )
  IDLE_S : 
    begin
      if( csr[15:13] == 3'b000 )
        next_case = WR_ONLY_S;
    end
  WR_ONLY_S : 
    begin
    end
  RD_ONLY_S : 
    begin
    end
  WR_RD_ONLY_S : 
    begin
    end
  WR_BURST_S : 
    begin
    end
  RD_BURST_S : 
    begin
    end
  WR_RD_BURST_S : 
    begin
    end
  default : 
    begin
    end
  endcase

endmodule

always_ff @( posedge clk_i, posedge rst_i )
if( st_bit )
  test_cnt <= '0;
else if( load_test_cnt )
  test_cnt <= csr[2];
else if( test_finished )
  test_cnt <= test_cnt - 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    reg_addr <= '0;
  else if( start_test_bit )
    case( csr[1][12:10] )
      3'b000 : reg_addr <= csr[3];
      3'b001, 3'b100 : reg_addr <= rnd_addr;
      3'b010 : reg_addr <= start_position_for_0;
      3'b011 : reg_addr <= '0;
      default : reg_addr <= '0;
  else if( inc_addr )
    reg_addr <= reg_addr + 1;
  else if( running_one )
    reg_addr <= reg_addr << 1;
  else if( running_zero )
    reg_addr <= reg_addr;

    
    else if( load_reg_addr )
    if( rnd_addr_apply )
      reg_addr <= rnd_addr; 
    else
      reg_addr <= csr[3];
  else if( inc_addr )
    reg_addr <= reg_addr + 1;
  else if( running_one )
    reg_addr <= reg_addr << 1;
  else if( running_zero )
    reg_addr <= reg_addr;

    else


