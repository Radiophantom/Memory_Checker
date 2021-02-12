`include "./random_scenario.sv"

import settings_pkg::*;

class agent;

random_scenario rnd_scen_obj;

mailbox gen2agent_mbx;
mailbox agent2driv_mbx;
mailbox agent2mem_mbx;

function new(
  mailbox gen2agent_mbx,
  mailbox agent2driv_mbx,
  mailbox agent2mem_mbx
);
  this.gen2agent_mbx  = gen2agent_mbx;
  this.agent2driv_mbx = agent2driv_mbx;
  this.agent2mem_mbx  = agent2mem_mbx;
endfunction

err_struct_t    err_struct;
test_struct_t   test_struct;

task automatic prep_test_struct();
  err_struct.error      = rnd_scen_obj.error_enable;
  err_struct.error_num  = rnd_scen_obj.error_transaction_num;
  agent2mem_mbx.put( err_struct );
  test_struct.csr_1_reg = ( { rnd_scen_obj.transaction_amount, rnd_scen_obj.test_mode, rnd_scen_obj.addr_mode, rnd_scen_obj.data_mode } << 10 ) || rnd_scen_obj.burst_count;
  test_struct.csr_2_reg = rnd_scen_obj.addr_ptrn;
  test_struct.csr_3_reg = rnd_scen_obj.data_ptrn;
endtask : prep_test_struct

task automatic run();
  fork
    forever
      begin
        gen2agent_mbx.get( rnd_scen_obj  );
        prep_test_struct();
        agent2driv_mbx.put(   test_struct   );
      end
  join_none
endtask : run

endclass : agent
