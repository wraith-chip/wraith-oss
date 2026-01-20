import os
import math
import sys
import subprocess

objdump = "/class/ece411/riscv/bin/riscv64-unknown-elf-objdump"
objcopy = "/class/ece411/riscv/bin/riscv64-unknown-elf-objcopy"
gcc     = "/class/ece411/riscv/bin/riscv64-unknown-elf-gcc"

bytesperline = 4
addltag      = ""

gcc_args = "-mcmodel=medany -static -fno-common -ffreestanding -nostartfiles -lm -static-libgcc -lgcc -lc -Wl,--no-relax -march=rv32im -mabi=ilp32 -O2 -Wall -Wextra -Wno-unused"


if len(sys.argv) < 3:
    sys.exit("[err] Insufficient arg count")

if int(sys.argv[2]) > 1:
    sys.exit("[err] invalid core")

prog = sys.argv[1]
core = sys.argv[2]

if len(sys.argv) >= 4:
    bytesperline = int(sys.argv[3])
    addltag = f"_{bytesperline*8}"

if prog.endswith(".c") or prog.endswith(".s"):
    progname = os.path.basename(prog)[:-2]
    # c prog or asm
    os.makedirs("./memgen", exist_ok=True)
    os.system(f"{gcc} {gcc_args} \
    {os.path.dirname(os.path.abspath(__file__))}/startup.s {prog} -T \
    {os.path.dirname(os.path.abspath(__file__))}/link{core}.ld -o \
    ./memgen/{progname}{core}.elf")

elif prog.endswith(".cpp"):
    progname = os.path.basename(prog)[:-4]
    # c prog or asm
    os.makedirs("./memgen", exist_ok=True)
    os.system(f"{gcc} {gcc_args} \
    {os.path.dirname(os.path.abspath(__file__))}/startup.s {prog} -T \
    {os.path.dirname(os.path.abspath(__file__))}/link{core}.ld -o \
    ./memgen/{progname}{core}.elf")

elif prog.endswith(".elf"):
    print(f"[warn] supplied a precompiled ELF on core {core}")
    progname = os.path.basename(prog)[:-4]
    os.makedirs("./memgen", exist_ok=True)
    os.system(f"cp {prog} ./memgen/{progname}{core}.elf")

elif prog.endswith(".mem"):
    # don't need to do anything here
    print(f"[warn] supplied a precompiled memory image on core {core}")
    progname = os.path.basename(prog)[:-4]
    os.system(f"cp {prog} ./memgen/{progname}{core}{addltag}.mem")

    try:
        os.remove(f"./memgen/latest{core}{addltag}.mem")
    except FileNotFoundError:
        pass

    os.symlink(f"{os.getcwd()}/memgen/{progname}{core}{addltag}.mem", f"./memgen/latest{core}{addltag}.mem")
    print(f"[inf] symlinked to ./memgen/latest{core}{addltag}.mem")

    exit()

else:
    sys.exit("invalid file passed as arg")

res = subprocess.check_output(f"{objdump} -h ./memgen/{progname}{core}.elf", shell=True).decode("utf-8")
sections = [x.strip().split() for x in res.splitlines()[5::2]]

out = open(f"./memgen/{progname}{core}{addltag}.mem", "w")

for sec in sections:
    if int(sec[2], 16) == 0:
        continue

    os.system(f"{objcopy} -O binary -j {sec[1]} ./memgen/{progname}{core}.elf ./memgen/temp.bin")
    if not os.path.isfile("./memgen/temp.bin"):
        sys.exit("[err] Could not binarize some section of the ELF")

    f = open("./memgen/temp.bin", "rb")
    dat = f.read()

    out.write(f"@{int(sec[3], 16) >> int(math.log2(bytesperline)):08x}\n")
    for k in range(len(dat)//(bytesperline)):
        wind = "".join([f"{dat[k*bytesperline + v]:02x}" for v in range(bytesperline)[::-1]])
        out.write(f"{wind}\n")

    out.write("\n")

    f.close()

    os.remove("./memgen/temp.bin")

out.close()
print(f"[inf] dumped results to ./memgen/{progname}{core}{addltag}.mem")

try:
    os.remove(f"./memgen/latest{core}{addltag}.mem")
except FileNotFoundError:
    pass

os.symlink(f"{os.getcwd()}/memgen/{progname}{core}{addltag}.mem", f"./memgen/latest{core}{addltag}.mem")
print(f"[inf] symlinked to ./memgen/latest{core}{addltag}.mem")
