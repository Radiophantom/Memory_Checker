import settings_pkg::*;

class random_scenario();

int read_only_mode;
int write_only_mode;
int write_read_mode;

int fix_addr_mode;
int rnd_addr_mode;
int run_1_addr_mode;
int run_0_addr_mode;
int inc_addr_mode;

int err_probability;
int no_err_probability;

bit [2 : 0][31 : 0] test_parameters;

rand bit [11 : 0]           transaction_amount;
rand bit [1 : 0]            test_mode;
rand bit [2 : 0]            addr_mode;
rand bit                    data_mode;
rand bit [BURST_W - 2 : 0]  burst_count;

rand bit                    error_enable;
bit      [11 : 0]           error_transaction_num;

constraint test_mode_constraint {
  test_mode dist {
    0 := 0,
    1 := read_only_mode,
    2 := write_only_mode,
    3 := write_read_mode
  };
}

constraint addr_mode_constraint {
  addr_mode dist {
    0     := fix_addr_mode,
    1     := rnd_addr_mode,
    2     := run_0_addr_mode,
    3     := run_1_addr_mode,
    4     := inc_addr_mode,
    [5:7] := 0
  };
}

constraint error_enable_constraint {
  error_enable dist {
    0 := no_err_probability,
    1 := err_probability
  };
}

bit [ADDR_W - 1 : 0]   addr_ptrn; //rand add if no post_randomize() function
bit [7 : 0]            data_ptrn; //rand add if no post_randomize() function

function automatic void set_test_mode_probability(
  int read_only_mode  = 10,
  int write_only_mode = 10,
  int write_read_mode = 10
);
  this.read_only_mode   = read_only_mode;
  this.write_only_mode  = write_only_mode;
  this.write_read_mode  = write_read_mode;
endfunction

function automatic void set_addr_mode_probability(
  int fix_addr_mode   = 10,
  int rnd_addr_mode   = 10,
  int run_0_addr_mode = 10,
  int run_1_addr_mode = 10,
  int inc_addr_mode   = 10
);
  this.fix_addr_mode    = fix_addr_mode;
  this.rnd_addr_mode    = rnd_addr_mode;
  this.run_0_addr_mode  = run_0_addr_mode;
  this.run_1_addr_mode  = run_1_addr_mode;
  this.inc_addr_mode    = inc_addr_mode;
endfunction

function automatic void set_err_probability(
  int err_probability     = 5,
  int no_err_probability  = 100
);
  this.err_probability    = err_probability;
  this.no_err_probability = no_err_probability;
endfunction

function automatic void create_scenario();
  test_parameters[2][31 : 0]  = { transaction_amount, 2'b00, test_mode, addr_mode, data_mode, 1'b0, burst_count };
  test_parameters[1][31 : 0]  = addr_ptrn;
  test_parameters[0][31 : 0]  = data_ptrn;
endfunction

// Можно вообще удалить и оставить как есть, но хочу попробовать использовать
// эту функцию
function automatic void post_randomize();
  if( addr_mode == 0 || addr_mode == 4 )
    randomize( addr_ptrn );
  if( ~data_mode )
    randomize( data_ptrn );
endfunction

endclass
