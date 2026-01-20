import random

N = random.randint(0, 511)  # Random N in [0, 511]

for _ in range(N):
    val = random.getrandbits(32)
    print(f"{val:08X}")

