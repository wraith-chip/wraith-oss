import random
import numpy as np
from functools import reduce
from mapper_utils import MeshDir, Action, Constant

actions = []

for i in range(0, 8):
    pid = i + 2

    # Node 4 ingress, goes to Node 0. All 8 PIDs will modulo RF within this one
    actions.append(Action(4, pid, 0, 30, MeshDir.TOP, 0, False, False, pid))
    # Node 0 "swaps" to get the previous operand
    actions.append(Action(0, pid, 5, (i - 1)%8, MeshDir.RIGHT, i, True, True, pid))
    # Node 1 scales the previous element by a new constant
    actions.append(Action(1, pid, 0, 31, MeshDir.BOTTOM, 0, False, False, pid))
    # Node 5 combines the two. This is first filt2
    actions.append(Action(5, pid, 0, i, MeshDir.RIGHT, 0, False, False, pid))

    # Cluster 2 computes two new filters
    actions.append(Action(6, pid, 0, 31, MeshDir.TOP, 16+i, True, True, pid))
    actions.append(Action(2, pid, 0, (16 + i-1)%24, MeshDir.RIGHT, 0, False, False, pid))

    actions.append(Action(3, pid, 0, 30, MeshDir.BOTTOM, 8+i, True, True, pid))
    actions.append(Action(7, pid, 0, (8 + i-1)%16, MeshDir.BOTTOM, 0, False, False, pid))

    # Cluster 3
    actions.append(Action(11, pid, 0, 30, MeshDir.BOTTOM, 8+i, True, True, pid))
    actions.append(Action(15, pid, 0, (8 + i-1)%16, MeshDir.LEFT, 0, False, False, pid))

    actions.append(Action(14, pid, 0, 31, MeshDir.TOP, 16+i, True, True, pid))
    actions.append(Action(10, pid, 0, (16 + i-1)%24, MeshDir.LEFT, 0, False, False, pid))

    # Cluster 4
    actions.append(Action(9, pid, 0, 30, MeshDir.BOTTOM, 8+i, True, True, pid))
    actions.append(Action(13, pid, 0, (8 + i-1)%16, MeshDir.LEFT, 0, False, False, pid))

    actions.append(Action(12, pid, 0, 31, MeshDir.TOP, 16+i, True, True, pid))
    actions.append(Action(8, pid, 0, (16 + i-1)%24, MeshDir.LEFT, 0, False, False, pid))

actions.sort(key=lambda x: x.coord, reverse=True)

cfg = open("./out.cfg", "w")
for action in actions:
    cfg.write(f"{action.pack():08x}\n")
cfg.close()

# Post-HK problem: Approximate complex roots with real ones
# ---K
# filter = [120, 24, 6, 2, 1]
# print(np.roots(filter))
# roots = np.roots(filter)
# subfilts = [[1/r, 1] for r in roots]

roots = [2, 6, 7, 13, 14, 8, 5]
subfilts = [[r, 1] for r in roots]

# first filter will have some scalar to account for root scaling
subfilts[0][0] *= 2
subfilts[0][1] *= 2

res = reduce(lambda x, y: np.convolve(x, y, mode="full"), subfilts)
print(res) # visually confirm equivalence to input
