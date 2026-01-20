//  SPDX-License-Identifier: MIT
//  main.cpp — Poltergeist Simulator
//  Owner: Pradyun Narkadamilli

#include "types.hpp"

uint32_t alu_fu(uint32_t a, uint32_t b, uint8_t sel) {
  switch (sel) {
  case 0:
    return a + b;
  case 1:
    return a << (b & 0x1F);
  case 2:
    return a >> (b & 0x1F); // should be signed downshift
  case 3:
    return a - b; // reg bypass
  case 4:
    return a ^ b;
  case 5:
    return b;
  case 6:
    return a | b;
  case 7:
    return a & b;
  }

  return -1;
}

uint32_t mul_fu(uint32_t a, uint32_t b, uint8_t sel) {
  int64_t res = -1;

  switch (sel) {
  case 0:
    res = ((int64_t)a) * ((int64_t)b);
    break;
  case 1:
    res = ((int64_t)a) * ((uint64_t)b);
    break;
  case 2:
    res = a * b;
    break;
  case 3:
    res = a * b;
    break;
  }

  if (sel > 0)
    return ((uint32_t)(res >> 32));
  else
    return (uint32_t)res;
}

bool pe_cycle(pe &cell) {
  bool serviced = false;
  // service buffered packet, if it exists
  if (cell.haspkt) {
    if (cell.bufpkt.pid == 0) {
      auto &newaction = cell.bufpkt.imm.tableWrite;
      if (newaction.coord == cell.coord) {
        cell.table[newaction.tableidx] = translateEntry(cell.bufpkt.imm);
      } else {
        uint8_t dir =
            ((newaction.coord - cell.coord) % 4 == 0) ? MBOTTOM : MRIGHT;
        if (cell.eg[dir]->size() == FIFO_DEPTH)
          return true;
        *(cell.egvld[dir]) = true;
        *(cell.egbuf[dir]) = cell.bufpkt;
      }

      cell.haspkt = false;
      serviced = true;
    } else if (cell.bufpkt.pid == 1) {
      auto &newconst = cell.bufpkt.imm.constLoad;
      if (newconst.coord == cell.coord) {
        cell.regs[newconst.rdidx] = (uint32_t)newconst.constant;
      } else {
        uint8_t dir =
            ((newconst.coord - cell.coord) % 4 == 0) ? MBOTTOM : MRIGHT;
        if (cell.eg[dir]->size() == FIFO_DEPTH)
          return true;
        *(cell.egvld[dir]) = true;
        *(cell.egbuf[dir]) = cell.bufpkt;
      }

      cell.haspkt = false;
      serviced = true;
    } else {
      auto &action = cell.table[cell.bufpkt.pid];

      if (action.egidx < 5 && cell.eg[action.egidx]->size() == FIFO_DEPTH)
        return true;

      int reg = cell.regs[action.rsidx];
      int imm = cell.bufpkt.imm.imm;
      int res = cell.mul ? mul_fu(imm, reg, action.fu_op)
                         : alu_fu(imm, reg, action.fu_op);

      if (action.egidx < 5) {
        *(cell.egvld[action.egidx]) = true;
        cell.egbuf[action.egidx]->pid = action.respid;
        cell.egbuf[action.egidx]->imm.imm = res;
      }

      if (action.rd_wr) {
        cell.regs[action.rdidx] = action.imm_wr ? imm : res;
      }

      cell.haspkt = false;
      serviced = true;
    }
  }

  // round robin dequeue, if we can get rid of our packet
  if (!cell.haspkt) {
    for (int i = 0; i < 5; i++) {
      int idx = (i + cell.lastrr + 1) % 5;
      if (cell.ig[idx].size() == 0)
        continue;

      cell.deqpending = true;
      cell.lastrr = idx;
    }
  }

  // did we do something this cycle?
  return serviced || cell.haspkt || cell.deqpending;
}

void pe_enq_deq(pe &cell) {
  for (int i = 0; i < 5; i++) {
    if (cell.igvld[i]) {
      cell.ig[i].push(cell.igbuf[i]);
      if (VERBOSE > 2) {
        std::cout << "[inf] enq @ " << std::dec << (int)cell.coord;
        std::cout << " pid:" << std::dec << (int)cell.igbuf[i].pid;
        std::cout << " dir:" << std::dec << i << "\n";
      }
    }
    cell.igvld[i] = false;
  }

  if (cell.deqpending) {
    cell.haspkt = true;
    cell.bufpkt = cell.ig[cell.lastrr].front();
    cell.ig[cell.lastrr].pop();

    if (VERBOSE > 2) {
      std::cout << "[inf] deq @ " << std::dec << (int)cell.coord;
      std::cout << " pid:" << std::dec << (int)cell.bufpkt.pid;
      std::cout << " dir:" << std::dec << (int)cell.lastrr;
      std::cout << " imm: " << std::hex << std::setw(8) << std::setfill('0')
                << cell.bufpkt.imm.imm << "\n";
    }
  }

  cell.deqpending = false;
}

pe **make_mesh() {
  pe **mesh = new pe *[4];
  for (int i = 0; i < 4; i++)
    mesh[i] = new pe[4];

  // link the mesh together
  for (int i = 0; i < 3; i++)
    for (int j = 0; j < 4; j++) {
      mesh[i][j].eg[MRIGHT] = &mesh[i + 1][j].ig[MLEFT];
      mesh[i + 1][j].eg[MLEFT] = &mesh[i][j].ig[MRIGHT];

      mesh[i][j].egvld[MRIGHT] = &mesh[i + 1][j].igvld[MLEFT];
      mesh[i + 1][j].egvld[MLEFT] = &mesh[i][j].igvld[MRIGHT];

      mesh[i][j].egbuf[MRIGHT] = &mesh[i + 1][j].igbuf[MLEFT];
      mesh[i + 1][j].egbuf[MLEFT] = &mesh[i][j].igbuf[MRIGHT];
    }

  for (int i = 0; i < 4; i++)
    for (int j = 0; j < 3; j++) {
      mesh[i][j].eg[MBOTTOM] = &mesh[i][j + 1].ig[MTOP];
      mesh[i][j + 1].eg[MTOP] = &mesh[i][j].ig[MBOTTOM];

      mesh[i][j].egvld[MBOTTOM] = &mesh[i][j + 1].igvld[MTOP];
      mesh[i][j + 1].egvld[MTOP] = &mesh[i][j].igvld[MBOTTOM];

      mesh[i][j].egbuf[MBOTTOM] = &mesh[i][j + 1].igbuf[MTOP];
      mesh[i][j + 1].egbuf[MTOP] = &mesh[i][j].igbuf[MBOTTOM];
    }

  for (int i = 0; i < 4; i += 2)
    for (int j = 0; j < 4; j += 2) {
      mesh[i][j].eg[4] = &mesh[i + 1][j + 1].ig[4];
      mesh[i + 1][j + 1].eg[4] = &mesh[i][j].ig[4];

      mesh[i][j].egvld[4] = &mesh[i + 1][j + 1].igvld[4];
      mesh[i + 1][j + 1].egvld[4] = &mesh[i][j].igvld[4];

      mesh[i][j].egbuf[4] = &mesh[i + 1][j + 1].igbuf[4];
      mesh[i + 1][j + 1].egbuf[4] = &mesh[i][j].igbuf[4];
    }

  for (int i = 1; i < 4; i += 2)
    for (int j = 0; j < 4; j += 2) {
      mesh[i][j].eg[4] = &mesh[i - 1][j + 1].ig[4];
      mesh[i - 1][j + 1].eg[4] = &mesh[i][j].ig[4];

      mesh[i][j].egvld[4] = &mesh[i - 1][j + 1].igvld[4];
      mesh[i - 1][j + 1].egvld[4] = &mesh[i][j].igvld[4];

      mesh[i][j].egbuf[4] = &mesh[i - 1][j + 1].igbuf[4];
      mesh[i - 1][j + 1].egbuf[4] = &mesh[i][j].igbuf[4];
    }

  for (int i = 0; i < 4; i++)
    for (int j = 0; j < 4; j++) {
      mesh[i][j].coord = j * 4 + i;
      mesh[i][j].mul = (i + (j % 2)) % 2;
    }

  for (int i = 0; i < 2; i++)
    for (int j = 0; j < 2; j++) {
      auto regs = new uint32_t[32];
      mesh[i * 2][j * 2].regs = regs;
      mesh[i * 2 + 1][j * 2].regs = regs;
      mesh[i * 2][j * 2 + 1].regs = regs;
      mesh[i * 2 + 1][j * 2 + 1].regs = regs;
    }

  return mesh;
}

void teardown_mesh(pe **mesh) {
  for (int i = 0; i < 2; i++)
    for (int j = 0; j < 2; j++)
      delete[] mesh[i * 2][j * 2].regs;

  for (int i = 0; i < 4; i++)
    delete[] mesh[i];
  delete[] mesh;
}

void mesh_state_dump(pe **mesh) {
  std::ofstream tableDmp("tables.dmp");

  if (!tableDmp.is_open()) {
    std::cerr << "Error: Could not open the file for writing." << std::endl;
  }

  for (int j = 0; j < 4; j++)
    for (int i = 0; i < 4; i++) {
      tableDmp << "Cell " << (i + j * 4) << "\n----\n";

      for (int k = 2; k < 16; k++) {
        tableDmp << "PID: " << std::setw(2) << k;
        tableDmp << " Op: " << (int)mesh[i][j].table[k].fu_op;
        tableDmp << " RS: " << std::setw(2) << (int)mesh[i][j].table[k].rsidx;
        tableDmp << " Egress Dir: " << (int)mesh[i][j].table[k].egidx;
        tableDmp << " RD: " << (int)mesh[i][j].table[k].rdidx;
        tableDmp << " IMM BP: " << (int)mesh[i][j].table[k].imm_wr;
        tableDmp << " RPID: " << std::setw(2)
                 << (int)mesh[i][j].table[k].respid;
        tableDmp << "\n";
      }
      tableDmp << "\n";
    }

  tableDmp.close();

  std::ofstream regDmp("regs.dmp");

  if (!regDmp.is_open()) {
    std::cerr << "Error: Could not open the file for writing." << std::endl;
  }

  regDmp << std::setfill('0');

  for (int j = 0; j < 2; j++)
    for (int i = 0; i < 2; i++) {
      regDmp << "Cluster " << (i + j * 2) << "\n----\n";

      for (int k = 0; k < 32; k++) {
        regDmp << " x" << std::setw(2) << std::dec << k << ": 0x"
               << std::setw(8) << std::hex << mesh[i * 2][j * 2].regs[k]
               << std::endl;
      }
      regDmp << "\n";
    }

  regDmp.close();
}

std::queue<wimpPkt> sim_mesh(pe **mesh, std::queue<wimpPkt> spm_ig, bool ig_sel,
                             uint32_t &cycles) {
  bool top_egvld = false;
  bool bot_egvld = false;
  wimpPkt top_egbuf, bot_egbuf;
  std::queue<wimpPkt> spm_eg, dummy;

  // TODO: indicate what the egress is in bitstream
  mesh[0][2].eg[MLEFT] = &dummy;
  mesh[0][2].egvld[MLEFT] = &top_egvld;
  mesh[0][2].egbuf[MLEFT] = &top_egbuf;

  mesh[0][3].eg[MLEFT] = &dummy;
  mesh[0][3].egvld[MLEFT] = &bot_egvld;
  mesh[0][3].egbuf[MLEFT] = &bot_egbuf;

  bool alive = true;
  while (alive) {
    if (!spm_ig.empty() && mesh[0][ig_sel].ig[MLEFT].size() < FIFO_DEPTH) {
      mesh[0][ig_sel].igvld[MLEFT] = true;
      mesh[0][ig_sel].igbuf[MLEFT] = spm_ig.front();

      spm_ig.pop();
    }

    if (top_egvld) {
      spm_eg.push(top_egbuf);
    }
    if (bot_egvld) {
      spm_eg.push(bot_egbuf);
    }

    top_egvld = false;
    bot_egvld = false;

    for (int i = 0; i < 4; i++)
      for (int j = 0; j < 4; j++)
        pe_enq_deq(mesh[i][j]);

    alive = false;
    for (int i = 0; i < 4; i++)
      for (int j = 0; j < 4; j++) {
        alive |= pe_cycle(mesh[i][j]);
      }

    cycles++;
  }

  mesh[0][2].eg[MLEFT] = NULL;
  mesh[0][2].egvld[MLEFT] = NULL;
  mesh[0][2].egbuf[MLEFT] = NULL;

  mesh[0][3].eg[MLEFT] = NULL;
  mesh[0][3].egvld[MLEFT] = NULL;
  mesh[0][3].egbuf[MLEFT] = NULL;

  return spm_eg;
}

int main(int argc, char *argv[]) {
  if (argc < 4) {
    std::cerr << "[err] invalid arg count" << std::endl;
    return -1;
  }

  pe **mesh = make_mesh();

  uint32_t cycles = 0;

  std::queue<wimpPkt> configPkts;
  std::ifstream config(argv[1]);
  uint32_t configLine;

  while (config >> std::hex >> configLine) {
    configPkts.push({0, {configLine}});
  }

  sim_mesh(mesh, configPkts, false, cycles);
  std::cout << "[inf] config completed after " << std::dec << cycles
            << " cycles\n";

  std::queue<wimpPkt> constPkts;
  std::ifstream consts(argv[2]);
  uint32_t constLine;

  while (consts >> std::hex >> constLine) {
    constPkts.push({1, {constLine}});
  }

  sim_mesh(mesh, constPkts, false, cycles);
  std::cout << "[inf] constants loaded after " << std::dec << cycles
            << " cycles\n";

  std::queue<wimpPkt> dataPkts;
  std::ifstream data(argv[3]);
  uint32_t dataLine;

  while (data >> std::hex >> dataLine) {
    uint8_t pid = (dataLine >> 28);
    uint32_t imm =
        (dataLine & 0xFFFFFFF) | (dataLine & 0x8000000 ? 0xF0000000 : 0);
    dataPkts.push({pid, {imm}});
  }

  auto spm_eg = sim_mesh(mesh, dataPkts, true, cycles);
  std::cout << "[inf] kernel streamed out after " << std::dec << cycles
            << " cycles\n";
  std::cout << "[inf] kernel produced " << std::dec << spm_eg.size()
            << " outputs\n";

  std::ofstream spmDmp("spm_eg.dmp");

  if (!spmDmp.is_open()) {
    std::cerr << "Error: Could not open the file for writing." << std::endl;
  }

  while (!spm_eg.empty()) {
    spmDmp << "0x" << std::setfill('0') << std::setw(8) << std::hex
           << spm_eg.front().imm.imm;
    spmDmp << std::dec << " (" << spm_eg.front().imm.imm << ")" << std::endl;
    spm_eg.pop();
  }

  // Dump out the routing table & rf state
  mesh_state_dump(mesh);
  teardown_mesh(mesh);
}
