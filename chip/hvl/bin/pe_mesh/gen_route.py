#!/usr/bin/python3
from typing import List
ROOT_PID = 2
class Payload:
  # These are all ugly binary value strings cuz im lazy
  x: int #todo
  y: int #todo
  op: str
  src: str
  dest: str
  response_pid: str
  rd: str

  def __init__(self, x, y, op, src, dest, response_pid, rd):
      self.x = x
      self.y = y
      self.op = op # fu func id
      self.src = src # reg id
      self.dest = dest # egress id
      self.response_pid = response_pid # pid
      self.rd = rd # reg id

  def __repr__(self):
      return (f"config_pkt(x:{self.x} and y:{self.y}, "
              f"op={self.op}, "
              f"src={self.src}, "
              f"dest={EgressIdName[self.dest]}, "
              f"response_pid={self.response_pid}, "
              f"rd={self.rd})")

Op = {
    "add" : "000",
    "sll" : "001",
    "sra" : "010",
    "sub" : "011",
    "xor" : "100",
    "srl" : "101",
    "or"  : "110",
    "and" : "111",

    "mul"     : "000",
    "mul_h"   : "001",
    "mul_hsu" : "010",
    "mul_hu"  : "011"
}

EgressId = {
    # x, y
    # top-left is (0,0)
    (0, -1): "000", # north
    (-1, 0): "001", # west
    (0, +1): "010", # south
    (+1, 0): "011", # east
    (0,0):   "111", # sink
}

EgressIdName = {
    "000": "north",
    "001": "west",
    "010": "south",
    "011": "east",
    "111": "sink"
}

# int to binary string bs
RegId = {i: bin(i)[2:].zfill(5) for i in range(32)}
Pid = {i: bin(i)[2:].zfill(4) for i in range(16)}
TwoBitFn = {i: bin(i)[2:].zfill(2) for i in range(4)}

def path_one() -> List[Payload]:
  lst: List[Payload] = []

  # Since we just want to stream some data through, use add operation?
  pid = Pid[ROOT_PID + 0]
  rsid = RegId[31]
  rdid = RegId[1]
  op = Op["add"]

  grid_size = 4
  path = []
  for y in range(grid_size):
      if y % 2 == 0:
          for x in range(grid_size):
              path.append((x, y))
      else:
          for x in range(grid_size - 1, -1, -1):
              path.append((x, y))
  if False:
    print(path)

  for i in range(len(path)):
      x_iter, y_iter = path[i]
      if i < len(path) - 1:
          next_x, next_y = path[i+1]
          dx, dy = next_x - x_iter, next_y - y_iter
          egressid = EgressId[(dx, dy)]
      else:
          if len(path) > 1:
              prev_x, prev_y = path[i-1]
              dx, dy = x_iter - prev_x, y_iter - prev_y
              opposite_direction = (-dx, -dy)
              egressid = EgressId.get(opposite_direction, "000")
          else:
              egressid = "SHOULD BE UNREACHABLE"

      response_pid = pid if i+1 < len(path) else Pid[ROOT_PID + 1]
      if i+1 == len(path):
        egressid = "001" # default to West

      lst.append(Payload(x_iter, y_iter, op, rsid, egressid, response_pid, rdid))


  return lst

x_fn = lambda x: TwoBitFn[x]
y_fn = lambda y: TwoBitFn[y]

ACTION_TABLE_IDX = Pid[2]

# print("action table:", ACTION_TABLE_IDX)

def payload_to_verilog_hex(payload: Payload) -> str:
  binstr = x_fn(payload.x) + y_fn(payload.y) + ACTION_TABLE_IDX + payload.op + payload.src + payload.dest + payload.response_pid + payload.rd + '0000'
  return hex(int(binstr, 2))[2:].upper().zfill(8)

for p in path_one():
    print(payload_to_verilog_hex(p))
    # print(p)
