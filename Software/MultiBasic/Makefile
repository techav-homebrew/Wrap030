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


#TOPTARGETS := all clean

#SUBDIRS := $(wildcard */.)

#$(TOPTARGETS): $(SUBDIRS)
#$(SUBDIRS):
#	$(MAKE) -C $@ $(MAKECMDGOALS)

#.PHONY: $(TOPTARGETS) $(SUBDIRS)

SUBDIRS := $(wildcard */.)

SRCS = $(wildcard */*.asm)
OBJS = $(patsubst %.asm,%.o,$(SRCS))

$(info DEBUG $(OBJS))

rom.srec: rom.out
	$(OC) $(OCFLAGS) rom.out -O srec rom.srec
	$(OC) $(OCFLAGS) rom.out -O ihex rom.hex
	$(OC) $(OCFLAGS) rom.out -O binary rom.bin

rom.out: $(OBJS)
	$(LD) $(LDFLAGS) -Map rom.map -o rom.out $^

$(OBJS): $(SRCS)
	$(info CALLING MAKE $(@F))
	$(MAKE) -C $(@D) $(@F)


clean: $(SUBDIRS)
$(SUBDIRS):
	$(MAKE) -C $@ $(MAKECMDGOALS)
	-$(RM) *.o *.out *.L68 *.srec *.map *.i *.hex *.bin
.PHONY: clean $(SUBDIRS)

burn: rom.srec
	$(PYTHON) ..\..\Utilities\srecLoadRAMwin.py COM6 rom.srec