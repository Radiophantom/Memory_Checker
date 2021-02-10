import settings_pkg::*;

class generator();

random_scenario rnd_scen_obj;

int test_amount = 1000;

function void new(
  mailbox wr_req_mbx,
  mailbox err_trans_req_mbx
);
  this.wr_req_mbx         = wr_req_mbx;
  this.err_trans_req_mbx  = err_trans_req_mbx;
endfunction

function automatic void run();
  while( test_amount )
    begin
      rnd_scen_obj = new();
      rnd_scen_obj.set_test_mode_probability();
      rnd_scen_obj.set_addr_mode_probability();
      rnd_scen_obj.set_err_probability();
      rnd_scen_obj.randomize();
      rnd_scen_obj.create_scenario();
      wr_req_mbx.put( rnd_scen_obj );
      if( rnd_scen_obj.error_enable )
        err_trans_req_mbx.put( error_transaction_num );
    end
endfunction

endclass
