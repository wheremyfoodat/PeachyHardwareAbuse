ASM=rgbasm -i GB/common

all: GB/CTF/ctf.gb GB/MMIO_exec_1/MMIO_exec_1.gb GB/Unused_mem_access/Unused_mem_access.gb 

GB/CTF/ctf.gb: .FORCE
	rgbgfx GB/CTF/ags-aging-font.png -o GB/CTF/ags-aging-font.chr
	$(ASM) GB/CTF/ctf.asm -o GB/CTF/ctf.o
	rgblink GB/CTF/ctf.o -o GB/CTF/ctf.gb
	rgbfix -v -p 0 GB/CTF/ctf.gb

GB/MMIO_exec_1/MMIO_exec_1.gb: .FORCE
	$(ASM) GB/MMIO_exec_1/MMIO_exec_1.asm -o GB/MMIO_exec_1/MMIO_exec_1.o
	rgblink GB/MMIO_exec_1/MMIO_exec_1.o -o GB/MMIO_exec_1/MMIO_exec_1.gb
	rgbfix -v -p 0 GB/MMIO_exec_1/MMIO_exec_1.gb

GB/Unused_mem_access/Unused_mem_access.gb: .FORCE
	$(ASM) GB/Unused_mem_access/Unused_mem_access.asm -o GB/Unused_mem_access/Unused_mem_access.o
	rgblink GB/Unused_mem_access/Unused_mem_access.o -o GB/Unused_mem_access/Unused_mem_access.gb
	rgbfix -v -p 0 GB/Unused_mem_access/Unused_mem_access.gb

# Always force a clean rebuild, this is Game Boy assembly, builds are fast.
.PHONY: .FORCE

clean:
	rm GB/CTF/ctf.o
	# rm GB/CTF/ctf.gb
	rm GB/CTF/ags-aging-font.chr
	rm GB/MMIO_exec_1/MMIO_exec_1.o
	# rm GB/MMIO_exec_1/MMIO_exec_1.gb
	rm GB/Unused_mem_access/Unused_mem_access.o
	# rm GB/Unused_mem_access/Unused_mem_access.gb