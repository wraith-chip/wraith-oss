from enum import Enum

# useful for any future mappers
class MeshDir(Enum):
    TOP = 0
    LEFT = 1
    BOTTOM = 2
    RIGHT = 3
    SINK = 7

class Action:
    def __init__(self, coord, pid, op, rs, eg, rd, imm_wr, rd_wr, r_id):
        rdrange = (coord & 0x1) + ((coord & 0x4) >> 1)
        if rd !=0 and rd not in range(rdrange*8, rdrange*8+8):
            print("[err] entry does not adhere to register banking rules")
            print(f"[err] coord: {coord} request: {rd} allotted: {rdrange*8} - {rdrange*8+7}")

        self.coord = coord
        self.pid   = pid

        self.op   = op
        self.rs   = rs
        self.eg   = eg
        self.rd   = rd
        self.imm_wr = imm_wr
        self.rd_wr  = rd_wr

        self.r_id = r_id

    def pack(self):
        #action formatting
        tmp  = self.r_id & 0xF
        tmp <<= 1
        tmp |= self.imm_wr & 0x1
        tmp <<= 1
        tmp |= self.rd_wr & 0x1
        tmp <<= 5
        tmp |= self.rd & 0x1F
        tmp <<= 3
        tmp |= self.eg.value & 0x7
        tmp <<= 5
        tmp |= self.rs & 0x1F
        tmp <<= 3
        tmp |= self.op & 0x7

        # delivery params
        tmp <<= 4
        tmp |= self.pid & 0xF
        tmp <<= 4
        tmp |= self.coord & 0xF

        return tmp

class Constant:
    def __init__(self, coord, rd, val):
        rdrange = (coord & 0x1) + ((coord & 0x4) >> 1)
        if rd !=0 and rd not in range(rdrange*8, rdrange*8+8):
            print("[err] entry does not adhere to register banking rules")
            print(f"[err] coord: {coord} request: {rd} allotted: {rdrange*8} - {rdrange*8+7}")

        self.coord = coord
        self.rd = rd
        self.val = val

    def pack(self):
        tmp = self.val & 0x7FFFFF
        tmp <<= 5
        tmp |= self.rd & 0x1F
        tmp <<= 4
        tmp |= self.coord & 0xF

        return tmp
