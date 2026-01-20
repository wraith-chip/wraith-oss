import sys

log = open(sys.argv[1], "r")

log0 = open(f"core0.log", "w")
log1 = open(f"core1.log", "w")

for line in log:
    addr = int(line.split(" ")[2][:8], 16)

    if addr < 0x80000000:
        log0.write(line)
    else:
        log1.write(line)

log0.close()
log1.close()
