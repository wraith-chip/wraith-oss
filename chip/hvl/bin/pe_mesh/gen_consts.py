
import random

mesh_height = 4
mesh_width = 4

num_regs = 30

reg_ranges = [2,7,8,15,16,23,24,30]

for i in range(mesh_height):
    for j in range(mesh_width):
        start_idx = reg_ranges[2*j]
        end_idx = reg_ranges[2*j+1]
        for k in range(start_idx, end_idx+1):
            # Compose the binary string
            bin_str = (
                "{:02b}".format(i) +
                "{:02b}".format(j) +
                "{:05b}".format(k) +
                "{:023b}".format(random.randint(0, 16000))
            )

            # Convert to integer
            val = int(bin_str, 2)

            # Print as 32-bit hex with leading zeros
            print(f"{val:08X}")

