import settings_pkg::*;

class statistics;

int wr_bytes        = 0;
int rd_bytes        = 0;
int wr_ticks        = 0;
int rd_ticks        = 0;
int rd_delay_ticks  = 0;
int rd_req_amount   = 0;

task automatic wr_bytes_cnt(  ref int bytes_amount  );
  wr_bytes += bytes_amount;
endtask : wr_bytes_cnt

task automatic rd_bytes_cnt(  ref int bytes_amount  );
  rd_bytes += bytes_amount;
endtask : rd_bytes_cnt

task automatic wr_ticks_cnt(  ref int ticks_amount  );
  wr_ticks += ticks_amount;
endtask : wr_ticks_cnt

task automatic rd_ticks_cnt(  ref int ticks_amount  );
  rd_ticks += ticks_amount;
endtask : rd_bytes_cnt

task automatic rd_delay_ticks_cnt(  ref int ticks_amount  );
  rd_delay_ticks += ticks_amount;
endtask : rd_delay_ticks_cnt

task automatic rd_req_amount_cnt( ref int req_amount  );
  rd_req_amount += req_amount;
endtask : rd_req_amount_cnt

endclass : statistics
