//  SPDX-License-Identifier: MIT
//  types.hpp — Poltergeist Types
//  Owner: Pradyun Narkadamilli

#include <queue>
#include <cstdint>
#include <fstream>
#include <iomanip>
#include <iostream>

#define VERBOSE 0
#define FIFO_DEPTH 2

#define MTOP    0
#define MLEFT   1
#define MBOTTOM 2
#define MRIGHT  3

typedef struct __attribute__((packed)) {
  uint16_t fu_op  : 3;
  uint16_t rsidx  : 5;
  uint16_t egidx  : 3;
  uint16_t rdidx  : 5;
  uint16_t rd_wr  : 1; // write to regfile
  uint16_t imm_wr : 1; // bypass imm into regfile

  uint16_t respid : 4;
} actionEntry;

typedef union {
  uint32_t imm;

  struct __attribute__((packed)) {
    uint16_t     coord    : 4;
    uint16_t     tableidx : 4;

    uint16_t fu_op  : 3;
    uint16_t rsidx  : 5;
    uint16_t egidx  : 3;
    uint16_t rdidx  : 5;
    uint16_t rd_wr  : 1; // bypass imm into regfile
    uint16_t imm_wr : 1; // bypass imm into regfile
    uint16_t respid : 4;

    uint16_t     padding  : 2;
  } tableWrite;

  struct __attribute__((packed)) {
    uint8_t     coord    : 4;
    uint16_t    rdidx    : 5;
    uint32_t    constant : 23;
  } constLoad;
} wimpImm;

actionEntry translateEntry(wimpImm imm) {
  return {imm.tableWrite.fu_op, imm.tableWrite.rsidx,
          imm.tableWrite.egidx, imm.tableWrite.rdidx,
          imm.tableWrite.rd_wr, imm.tableWrite.imm_wr,
          imm.tableWrite.respid};
}

typedef struct __attribute__((packed)) {
  uint8_t pid : 4;
  wimpImm  imm;
} wimpPkt;

typedef struct {
  uint8_t coord;

  // Port Ordering: TLBRC
  std::queue<wimpPkt> ig[5];
  bool                igvld[5] = { false };
  wimpPkt             igbuf[5];

  std::queue<wimpPkt>* eg[5]    = { NULL };
  bool*                egvld[5] = { NULL };
  wimpPkt*             egbuf[5] = { NULL };

  bool    deqpending = false;
  uint8_t lastrr     = 4;

  bool    haspkt = false;
  wimpPkt bufpkt;

  bool mul;

  actionEntry table[16];
  uint32_t    *regs;
} pe;
