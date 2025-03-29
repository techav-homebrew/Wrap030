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
	$(OC) $(OCFLAGS) rom.out -O ihex rom.hex

rom.out: exprom.o tsmon.o fpubasic.o
	$(LD) $(LDFLAGS) -Map rom.map -o rom.out $^
#	$(LD) $(LDFLAGS) -Map rom.map -o rom.out tsmon.o exprom.o fpubasic.o ide.o

tsmon.o:
	$(AS) $(ASFLAGS)="tsmon.L68" -o tsmon.o tsmon.s

exprom.o:
	$(AS) $(ASFLAGS)="exprom.L68" -o exprom.o exprom.s

fpubasic.o:
	$(AS) $(ASFLAGS)="fpubasic.L68" -o fpubasic.o fpubasic.s	

syscall: syscall.o
ide: ide.o
	$(CC) $(CFLAGS) -o $@ $^

clean:
	-$(RM) *.o *.out *.L68 *.srec *.map *.i

.PHONY: rebuild
rebuild:
	$(MAKE) clean
	$(MAKE) ROM

burn: rom.srec
	$(PYTHON) ..\..\Utilities\srecLoadWin.py rom.srec

ALL:
	$(MAKE) clean
	$(MAKE) ROM
	$(MAKE) burn

loadbasic: rambasic.srec
	$(PYTHON) ..\..\Utilities\srecLoadRAMwin.py COM6 rambasic.srec

rambasic.srec: rambasic.out
	$(OC) $(OCFLAGS) rambasic.out -O srec rambasic.srec

rambasic.out: fpubasic.o
	$(LD) -T rambasic.ld -Map rambasic.map -o rambasic.out fpubasic.o

.PHONY: reburn
reburn:
	$(MAKE) rebuild
	$(MAKE) burn