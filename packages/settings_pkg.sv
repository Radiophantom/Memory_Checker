package settings_pkg;

parameter int AMM_DATA_W    = 128,
parameter int AMM_ADDR_W    = 12,
parameter int CTRL_ADDR_W   = 10,
parameter int AMM_BURST_W   = 11,

parameter string ADDR_TYPE  = "BYTE",

parameter int RND_WAITREQ   = 0,
parameter int RND_RVALID    = 0

parameter int DATA_B_W = AMM_DATA_W/8,
parameter int ADDR_B_W = $clog2( DATA_B_W );
parameter int ADDR_W   = ( CTRL_ADDR_W - ADDR_B_W );

typedef enum logic {
  FIX_DATA,
  RND_DATA
} data_mode_type;

typedef enum logic [1:0] {
  READ_ONLY       = 1,
  WRITE_ONLY      = 2,
  WRITE_AND_CHECK = 3
} test_mode_type;

typedef enum logic [2:0] {
  FIX_ADDR  = 0,
  RND_ADDR  = 1,
  RUN_0     = 2,
  RUN_1     = 3,
  INC_ADDR  = 4
} addr_mode_type;

typedef struct{
  bit [ADDR_W - 1 : 0]  rd_start_addr;
  int                   words_amount ;
} rd_transaction_t;

typedef struct packed{
  logic [ADDR_W - 1        : 0] word_address;
  logic [AMM_BURST_W - 1   : 0] burst_word_count;
  logic [BYTE_PER_WORD - 1 : 0] start_mask;
  logic [BYTE_PER_WORD - 1 : 0] end_mask;
  logic [7 : 0]                 data_ptrn;
  logic                         data_ptrn_type;
} pkt_struct_t;

typedef struct packed{
  logic [ADDR_W - 1      : 0] word_address;
  logic [AMM_BURST_W - 1 : 0] high_burst_bits;
  logic [BYTE_ADDR_W     : 0] low_burst_bits;
  logic [BYTE_ADDR_W - 1 : 0] start_offset;
  logic [BYTE_ADDR_W - 1 : 0] end_offset;
} trans_struct_t;

endpackage
