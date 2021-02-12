`include "./random_scenario.sv"

class generator;

random_scenario rnd_scen_obj;

mailbox   gen2agent_mbx;

function new(
  mailbox gen2agent_mbx
);
  this.gen2agent_mbx = gen2agent_mbx;
endfunction

task automatic void run();
  repeat( 500 )
    begin
      rnd_scen_obj = new();
      rnd_scen_obj.set_test_mode_probability(10, 10, 10);
      rnd_scen_obj.set_addr_mode_probability();
      rnd_scen_obj.set_err_probability();
      rnd_scen_obj.randomize();
      gen2agent_mbx.put( rnd_scen_obj );
    end
  repeat( 500 )
    begin
      rnd_scen_obj = new();
      rnd_scen_obj.set_test_mode_probability(0, 0, 10);
      rnd_scen_obj.set_addr_mode_probability();
      rnd_scen_obj.set_err_probability();
      rnd_scen_obj.randomize();
      gen2agent_mbx.put( rnd_scen_obj );
    end
  repeat( 500 )
    begin
      rnd_scen_obj = new();
      rnd_scen_obj.set_test_mode_probability(0, 10, 0);
      rnd_scen_obj.set_addr_mode_probability();
      rnd_scen_obj.set_err_probability();
      rnd_scen_obj.randomize();
      gen2agent_mbx.put( rnd_scen_obj );
    end
  repeat( 500 )
    begin
      rnd_scen_obj = new();
      rnd_scen_obj.set_test_mode_probability(10, 0, 0);
      rnd_scen_obj.set_addr_mode_probability();
      rnd_scen_obj.set_err_probability();
      rnd_scen_obj.randomize();
      gen2agent_mbx.put( rnd_scen_obj );
    end
  repeat( 500 )
    begin
      rnd_scen_obj = new();
      rnd_scen_obj.set_test_mode_probability(10, 5, 5);
      rnd_scen_obj.set_addr_mode_probability();
      rnd_scen_obj.set_err_probability();
      rnd_scen_obj.randomize();
      gen2agent_mbx.put( rnd_scen_obj );
    end
  repeat( 500 )
    begin
      rnd_scen_obj = new();
      rnd_scen_obj.set_test_mode_probability(5, 10, 5);
      rnd_scen_obj.set_addr_mode_probability();
      rnd_scen_obj.set_err_probability();
      rnd_scen_obj.randomize();
      gen2agent_mbx.put( rnd_scen_obj );
    end
  repeat( 500 )
    begin
      rnd_scen_obj = new();
      rnd_scen_obj.set_test_mode_probability(5, 5, 10);
      rnd_scen_obj.set_addr_mode_probability();
      rnd_scen_obj.set_err_probability();
      rnd_scen_obj.randomize();
      gen2agent_mbx.put( rnd_scen_obj );
    end
endtask : run

endclass : generator
