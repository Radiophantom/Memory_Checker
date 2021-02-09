class bathtube_distribution;

int value;
int right_edge, seed, depth;

function automatic void set_dist_parameters(
  input int right_edge  = 1,
  input int seed        = 1,
  input int depth       = 4
);

  this.right_edge = right_edge - 1;
  this.seed       = seed;
  this.depth      = depth;

endfunction : set_dist_parameters

function automatic void pre_randomize();

  value = $dist_exponential( seed, depth );
  if( value > right_edge )
    value = right_edge;

  if( $urandom_range( 1 ) )
    value = right_edge - value;

  value = value + 1;

endfunction : pre_randomize

function automatic int get_value();

  return value;

endfunction : get_value

endclass : bathtube_distribution
