package fallback_types;



typedef enum logic [3:0] {
  in_idle,
  in_eat_bits,
  in_enqueue
} fb_fsm_in_t;

typedef enum logic [3:0] {
  out_idle,
  out_dequeue,
  out_w_bits
} fb_fsm_out_t;

endpackage;
