// Owner: Prakhar
package spm_types;

  typedef enum logic [2:0] {
    ssw_idle,
    ssw_get_addr,
    ssw_sram_wr,
    ssw_write_mesh
  }  spm_sram_write_fsm_t;

  typedef enum logic [2:0] {
    ssr_idle,
    ssr_get_pkts,
    ssr_wait_wb,
    ssr_magic,
    ssr_wb
  }  spm_sram_read_fsm_t;

endpackage
