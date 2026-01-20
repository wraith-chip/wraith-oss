import random
import numpy as np
from mapper_utils import MeshDir, Action, Constant

actions = []

modregs = list(range(16, 24)) + list(range(0, 8))

modlen = 8
leftlen = 8
for pid in range(2, 2+modlen):
    if pid - 2 < 8:
        # Node 4 ingress, goes to Node 0. All 8 PIDs will modulo RF within this one
        actions.append(Action(4, pid, 0, 30, MeshDir.TOP, modregs[(pid - 2) % modlen], False, True, pid))

        # Node 0 "swaps" to get the previous operand
        actions.append(Action(0, pid, 5, modregs[(pid - 3) % modlen], MeshDir.RIGHT, 0, True, False, pid))

    else:
        # Node 4 ingress, goes to Node 0. All 8 PIDs will modulo RF within this one
        actions.append(Action(4, pid, 0, 30, MeshDir.TOP, 0, False, False, pid))

        # Node 0 "swaps" to get the previous operand
        actions.append(Action(0, pid, 5, modregs[(pid - 3) % modlen],
                              MeshDir.RIGHT, modregs[(pid - 2) % modlen], True, True, pid))

    # Node 1 just scales by a const. We store this in 29
    actions.append(Action(1, pid, 0, 29, MeshDir.RIGHT, 0, False, False, pid))

    # Node 2 does a modulo RF swap again
    actions.append(Action(2, pid, 5, ((pid - 3) % leftlen), MeshDir.RIGHT,
                          ((pid - 2) % leftlen), True, True, pid))

    # Node 3 scales by a new const, stored in 30
    actions.append(Action(3, pid, 0, 30, MeshDir.BOTTOM, 0, False, False, pid))

    # Node 7 adds the item stored by Node 2 to this scaled thing
    actions.append(Action(7, pid, 0, ((pid - 2) % leftlen),
                          MeshDir.LEFT, 0, False, False, pid))

    # Node 6 is a bypass left
    actions.append(Action(6, pid, 0, 31, MeshDir.LEFT, 0, False, False, pid))

    # Node 5 adds what we wrote with Node 4, then passes down
    actions.append(Action(5, pid, 0, modregs[pid-2], MeshDir.BOTTOM, 0, False, False, pid))

    # Node 9 bypasses left
    actions.append(Action(9, pid, 0, 31, MeshDir.LEFT, 0, False, False, pid))

    # Node 8 is our egress. Bypass left.
    actions.append(Action(8, pid, 0, 30, MeshDir.LEFT, 0, False, False, pid))

sinkless = True
if sinkless:
    actions.append(Action(4, 2+modlen, 0, 0, MeshDir.TOP,    0, False, False, 2+modlen))
    actions.append(Action(0, 2+modlen, 0, 0, MeshDir.RIGHT,  0, False, False, 2+modlen))
    actions.append(Action(1, 2+modlen, 0, 0, MeshDir.RIGHT,  0, False, False, 2+modlen))
    actions.append(Action(2, 2+modlen, 0, 0, MeshDir.RIGHT,  0, False, False, 2+modlen))
    actions.append(Action(3, 2+modlen, 0, 0, MeshDir.BOTTOM, 0, False, False, 2+modlen))
    actions.append(Action(7, 2+modlen, 0, 0, MeshDir.LEFT,   0, False, False, 2+modlen))
    actions.append(Action(6, 2+modlen, 0, 0, MeshDir.LEFT,   0, False, False, 2+modlen))
    actions.append(Action(5, 2+modlen, 0, 0, MeshDir.BOTTOM, 0, False, False, 2+modlen))
    actions.append(Action(9, 2+modlen, 0, 0, MeshDir.LEFT,   0, False, False, 2+modlen))
    actions.append(Action(8, 2+modlen, 0, 0, MeshDir.LEFT,   0, False, False, 2+modlen))

else:
    actions.append(Action(4, 15, 0, 0, MeshDir.SINK, 0, False, False, 0))

rvtu_mul = True
if rvtu_mul:
    actions.append(Action(1, 11, 0, 0, MeshDir.SINK,   8, True,  True,  0))
    actions.append(Action(1, 12, 0, 8, MeshDir.TOP,    0, False, False, 12))
    actions.append(Action(1, 13, 1, 8, MeshDir.TOP,    0, False, False, 13))
    actions.append(Action(1, 14, 2, 8, MeshDir.TOP,    0, False, False, 14))
    actions.append(Action(1, 15, 3, 8, MeshDir.TOP,    0, False, False, 15))

    actions.append(Action(3, 11, 0, 0, MeshDir.SINK,   8, True,  True,  0))
    actions.append(Action(3, 12, 0, 8, MeshDir.TOP,    0, False, False, 12))
    actions.append(Action(3, 13, 1, 8, MeshDir.TOP,    0, False, False, 13))
    actions.append(Action(3, 14, 2, 8, MeshDir.TOP,    0, False, False, 14))
    actions.append(Action(3, 15, 3, 8, MeshDir.TOP,    0, False, False, 15))

actions.sort(key=lambda x: x.coord, reverse=True)

cfg = open("./out.cfg", "w")
for action in actions:
    cfg.write(f"{action.pack():08x}\n")
cfg.close()


filt = [2, 4, 8]

# using ints for now, proof of concept. Should scale to fixed point just fine.
a = filt[0]
b = int(filt[1]/filt[0])
c = int(filt[2]/filt[1])

# only need 3 consts!
constants = [
    Constant(5, 30, a),
    Constant(5, 29, b),
    Constant(7, 30, c),

    # bypass consts
    Constant(7,  31, 1),
    Constant(13, 30, 0),
    Constant(13, 31, 1),
]
constants.sort(key=lambda x: x.coord, reverse=True)

const = open("./out.const", "w")
for constant in constants:
    const.write(f"{constant.pack():08x}\n")
const.close()

dat = open("./out.dat", "w")
data = [0, 0] + [random.randint(0, 256) for i in range(0, 128)] +  [0, 0]
for i in range(len(data)):
    word = data[i] | (((i % modlen) + 2) << 28)
    dat.write(f"{word:08x}\n")

    if (i+1)%modlen == 0:
        word = (2+modlen) << 28
        for i in range(0, 15 - modlen):
            dat.write(f"{word:08x}\n")

dat.close()

print(np.convolve(filt, data, 'same'))
