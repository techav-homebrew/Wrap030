AS=m68k-elf-as
ASFLAGS=-m68882 -march=68030 -mcpu=68030 --base-size-default-16 -alhms
CC=m68k-elf-gcc
CFLAGS=-std=c99 -nostdlib -nodefaultlibs -fomit-frame-pointer -fno-builtin -m68030 -m68881 -nostartfiles -pie -save-temps -c
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

clean:
	-$(RM) *.o *.out *.L68 *.srec *.map *.i *.s

kernel.o:
	$(AS) $(ASFLAGS)="kernel.L68" -o kernel.o kernel.asm

vectors.o:
	$(AS) $(ASFLAGS)="vectors.L68" -o vectors.o vectors.asm

boot.o:
	$(AS) $(ASFLAGS)="boot.L68" -o boot.o boot.asm