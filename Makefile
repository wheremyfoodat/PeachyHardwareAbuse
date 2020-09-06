ASM=rgbasm -i GB/common

gb = \
	GB/CTF/ctf.gb \
	GB/MMIO_exec_1/MMIO_exec_1.gb \
	GB/Unused_mem_access/Unused_mem_access.gb \

all: $(gb)

ags-aging-font.chr:
	rgbgfx GB/CTF/ags-aging-font.png -o GB/CTF/ags-aging-font.chr

%.o: %.asm ags-aging-font.chr
	$(ASM) -o $@ $< 

%.gb: %.o .FORCE
	rgblink -o $@ $<
	rgbfix -v -p 0 $@

# Always force a clean rebuild, this is Game Boy assembly, builds are fast.
.PHONY: .FORCE

.PHONY: clean
clean:
	rm -f GB/CTF/ctf.o
	# rm GB/CTF/ctf.gb
	rm -f GB/CTF/ags-aging-font.chr
	rm -f GB/MMIO_exec_1/MMIO_exec_1.o
	# rm GB/MMIO_exec_1/MMIO_exec_1.gb
	rm -f GB/Unused_mem_access/Unused_mem_access.o
	# rm GB/Unused_mem_access/Unused_mem_access.gb