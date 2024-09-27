AS=m68k-elf-as
ASFLAGS=-m68882 -march=68030 -mcpu=68030 --base-size-default-16 -alhms

CC=m68k-elf-gcc
CFLAGS=-std=c99 -O1 -save-temps \
		-nostdlib -nodefaultlibs -fomit-frame-pointer \
		-fno-builtin -m68030 -m68881 -nostartfiles -pie -c

LD=m68k-elf-ld
LDFLAGS=--cref -T linker.ld

OC=m68k-elf-objcopy
OCFLAGS=

PYTHON=python.exe

# make Windows happy
ifeq ($(OS),Windows_NT) 
RM = del /Q /F
CP = copy /Y
ifdef ComSpec
SHELL := $(ComSpec)
endif
ifdef COMSPEC
SHELL := $(COMSPEC)
endif
else
RM = rm -rf
CP = cp -f
endif

ROM: rom.out
	$(OC) $(OCFLAGS) rom.out -O srec rom.srec

rom.out: Kernel/kernel.o Kernel/boot.o Kernel/vectors.o
	$(LD) $(LDFLAGS) -Map rom.map -o rom.out $^

clean:
	-$(RM) *.o *.out *.L68 *.srec *.map *.i
	$(MAKE) -C Kernel clean
	$(MAKE) -C EhBASIC clean
	

.PHONY: rebuild
rebuild:
	$(MAKE) clean
	$(MAKE) ROM

burn: rom.srec
	$(PYTHON) ..\..\Utilities\srecLoadRAMwin.py rom.srec