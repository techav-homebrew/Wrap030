AS=m68k-elf-as
ASFLAGS=-m68882 -march=68030 -mcpu=68030 --base-size-default-16 -alhms

CC=m68k-elf-gcc
CFLAGS=-std=c99 -O1 \
		-nostdlib -nodefaultlibs -fomit-frame-pointer \
		-fno-builtin -m68030 -m68881 -nostartfiles -pie -c

LD=m68k-elf-ld
LDFLAGS=--cref -T linker.ld

OC=m68k-elf-objcopy
OCFLAGS=

OD=m68k-elf-objdump

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

SRCS = $(wildcard *.asm)
OBJS = $(patsubst %.asm,%.o,$(SRCS))

ALL: $(OBJS)
	$(MAKE) $<

%.o: %.asm
	$(AS) $(ASFLAGS)="$*.L68" -o $@ $<

clean:
	-$(RM) *.o *.out *.L68 *.srec *.map *.i *.dump
