ramBot     = 0x00000000;
ramTop     = 0x001fffff;
stackTop   = ramTop + 1;

/*
romSector0 = 0x00200000;
romSector1 = 0x00210000;
*/

MEMORY
{
    rom (rx)  : ORIGIN = 0x00000000, LENGTH = 0x00080000
    ram (rwx) : ORIGIN = 0x00080000, LENGTH = 0x00180000
}

/*
MEMORY
{
    ram (rwx) : ORIGIN = 0x00000000, LENGTH = 0x00200000
    rom (rx)  : ORIGIN = 0x00200000, LENGTH = 0x00020000
}
*/

acia1Com = 0x00380000;
acia1Dat = acia1Com + 4;
acia2Com = acia1Com + 8;
acia2Dat = acia2Com + 4;

aciaRegDat = (0);
aciaRegCom = (4);

overlayPort = 0x00300000;
/*
romBot              = 0x00200000;
romTop              = 0x0021FFFF;
*/

romOffset           = 0x00200000;   /* position of ROM when overlay disabled */
romBot              = 0x00000000;
romTop              = 0x0007FFFF;
romSector0          = romBot;
romSector1          = romBot + 0x00010000;

ideBase             = 0x80200000;
ideCommand          = ideBase + 0x0000;
ideControl          = ideBase + 0x2000;
ideDataRW           = ideCommand + 0x0;
ideErrorRO          = ideCommand + 0x2;
ideFeatureWO        = ideCommand + 0x2;
ideSectorCountRW    = ideCommand + 0x4;
ideLBALLRW          = ideCommand + 0x6;
ideLBALHRW          = ideCommand + 0x8;
ideLBAHLRW          = ideCommand + 0xA;
ideLBAHHRW          = ideCommand + 0xC;
ideStatusRO         = ideCommand + 0xE;
ideCommandWO        = ideCommand + 0xE;
ideAltStatusRO      = ideControl + 0xC;
ideDevControlWO     = ideControl + 0xC;
ideDevAddressRO     = ideControl + 0xE;

comRegRX    = (0); /* Receive Buffer Register (read only) (Requires LCR DLAB clear) */
comRegTX    = (0); /* Transmit Holding Register (write only) (Requires LCR DLAB clear) */
comRegIER   = (1); /* Interrupt Enable Register */
comRegIIR   = (2); /* Interrupt Identification Register (read only) */
comRegFCR   = (2); /* FIFO Control Register (write only) */
comRegLCR   = (3); /* Line Control Register */
comRegMCR   = (4); /* Modem Control Register */
comRegLSR   = (5); /* Line Status Register */
comRegMSR   = (6); /* Modem Status Register */
comRegSPR   = (7); /* Scratch Pad Register */
comRegDivLo = (0); /* Divisor Latch Register LSB (Requires LCR DLAB set) */
comRegDivHi = (1); /* Divisor Latch Register MSB (Requires LCR DLAB set) */

io8base     = 0x80000000;
io8card0    = io8base;
io8card1    = io8base + 0x001000;
io8card2    = io8base + 0x002000;
io8card3    = io8base + 0x003000;
io8card4    = io8base + 0x004000;
io8card5    = io8base + 0x005000;
io8card6    = io8base + 0x006000;
io8card7    = io8base + 0x007000;

ioCom0      = io8card0 + 0x0000 + 0x00;
ioCom1      = io8card0 + 0x0000 + 0x08;
ioCom2      = io8card0 + 0x0000 + 0x10;
ioCom3      = io8card0 + 0x0000 + 0x18;
ioCom4      = io8card0 + 0x0800 + 0x20;
ioCom5      = io8card0 + 0x0800 + 0x28;
ioCom6      = io8card0 + 0x0800 + 0x30;
ioCom7      = io8card0 + 0x0800 + 0x38;

uMemSize    = 64 * 1024;
uMemSize0   = uMemSize;
uMemSize1   = uMemSize;
uMemSize2   = uMemSize;
uMemSize3   = uMemSize;
uMemSize4   = uMemSize;
uMemSize5   = uMemSize;
uMemSize6   = uMemSize;
uMemSize7   = uMemSize;
uMemSize8   = uMemSize;
uMemSize9   = uMemSize;
uMemSize10  = uMemSize;
uMemSize11  = uMemSize;
uMemSize12  = uMemSize;
uMemSize13  = uMemSize;
uMemSize14  = uMemSize;
uMemSize15  = uMemSize;

uSpoolSize    = 8 * 1024;
fileBufSize = 32 * 1024;

ENTRY(COLDBOOT)
SECTIONS{
    .kernel 0x00000000 :
    {
        Kernel/vectors.o (text)
        . = ALIGN(4);
        Kernel/boot.o (text)
        . = ALIGN(4);
        Kernel/kernel.o (text)
        . = ALIGN(4);
        Drivers/octocom.o (text)
        Drivers/acia.o (text)
        Spooler/spooler.o (text)
        . = ALIGN(4);
        Kernel/kernel.o (proc)
        /*USERTABLE = .;*/
        . = ALIGN(4);

        ROMBASIC = . ;
        RAMBASIC = . ;
        .basicStart = . ;
        EhBASIC/ehbasic.o (text)
        .basicEnd = . ;
    } > rom = 0xff
    .kglobals 0x00080000 (NOLOAD) :
    {
        Kernel/vectors.o ( bss )
        Kernel/boot.o ( bss )
        Kernel/kernel.o ( bss )
        Spooler/spooler.o ( bss )
    } > ram
    /*.kusertable 0x00090000 (NOLOAD) :
    {
        USERTABLE = . ;
    } > ram*/
    .spoolbuf 0x00090000 (NOLOAD) :
    {
        uBufStart0 = .;
        . += uSpoolSize;
        uBufStart1 = .;
        . += uSpoolSize;
        uBufStart2 = .;
        . += uSpoolSize;
        uBufStart3 = .;
        . += uSpoolSize;
        uBufStart4 = .;
        . += uSpoolSize;
        uBufStart5 = .;
        . += uSpoolSize;
        uBufStart6 = .;
        . += uSpoolSize;
        uBufStart7 = .;
        . += uSpoolSize;
    } > ram
    .fileBuf 0x000C0000 (NOLOAD) :
    {
        uFileStart0 = . ;
        . += fileBufSize;
        uFileStart1 = . ;
        . += fileBufSize;
        uFileStart2 = . ;
        . += fileBufSize;
        uFileStart3 = . ;
        . += fileBufSize;
        uFileStart4 = . ;
        . += fileBufSize;
        uFileStart5 = . ;
        . += fileBufSize;
        uFileStart6 = . ;
        . += fileBufSize;
        uFileStart7 = . ;
        . += fileBufSize;
    } > ram
    .kmmutable 0x000A0000 (NOLOAD) :
    {
        MMUTABLE = . ;
    } > ram

    .usermem 0x00100000 (NOLOAD) :
    {
        STACKINIT = . ;
        uMemStart = . ;
        
        uMemStart0 = . ;
        . += uMemSize0;
        uMemStart1 = . ;
        . += uMemSize1;
        uMemStart2 = . ;
        . += uMemSize2;
        uMemStart3 = . ;
        . += uMemSize3;
        uMemStart4 = . ;
        . += uMemSize4;
        uMemStart5 = . ;
        . += uMemSize5;
        uMemStart6 = . ;
        . += uMemSize6;
        uMemStart7 = . ;
        . += uMemSize7;
        uMemStart8 = . ;
        . += uMemSize8;
        uMemStart9 = . ;
        . += uMemSize9;
        uMemStart10 = . ;
        . += uMemSize10;
        uMemStart11 = . ;
        . += uMemSize11;
        uMemStart12 = . ;
        . += uMemSize12;
        uMemStart13 = . ;
        . += uMemSize13;
        uMemStart14 = . ;
        . += uMemSize14;
        uMemStart15 = . ;
        . += uMemSize15;
    } > ram
}



/*
ENTRY(COLDBOOT)
SECTIONS{
    .kernel 0x00200000 :
    {
        Kernel/vectors.o ( text )
        Kernel/boot.o ( text )
        Kernel/kernel.o ( text )
    } > rom = 0xff
    .null (NOLOAD) :
    {
        /* minimize what has to be written to ROM 
    } > rom = 0xff
    .basic 0x00210000 : /* put BASIC on second ROM sector 
    {
        ROMBASIC = . ;
        .basicStart = . ;
        EhBASIC/ehbasic.o( text )
        .basicEnd = . ;
    } > rom = 0xff
    .kglobals 0x00000400 (NOLOAD) :
    {
        Kernel/vectors.o ( bss )
        Kernel/boot.o ( bss )
        Kernel/kernel.o ( bss )
    } > ram
    .kusertable 0x00010000 (NOLOAD) :
    {
        USERTABLE = . ;
    } > ram
    .kmmutable 0x00020000 (NOLOAD) :
    {
        MMUTABLE = . ;
        SysTrapRAM = . ;
    } > ram
    .exebasic 0x00080000 (NOLOAD) :
    {
        RAMBASIC = . ;
        . += .basicEnd - .basicStart ;
        . = ALIGN(4);
    } > ram
    .usermem 0x00100000 (NOLOAD) :
    {
        STACKINIT = . ;
        uMemStart = . ;
        
        uMemStart0 = . ;
        . += uMemSize0;
        uMemStart1 = . ;
        . += uMemSize1;
        uMemStart2 = . ;
        . += uMemSize2;
        uMemStart3 = . ;
        . += uMemSize3;
        uMemStart4 = . ;
        . += uMemSize4;
        uMemStart5 = . ;
        . += uMemSize5;
        uMemStart6 = . ;
        . += uMemSize6;
        uMemStart7 = . ;
        . += uMemSize7;
    } > ram
}
*/

SIZEBASIC = .basicEnd - .basicStart ;
SUPVSTACKINIT = STACKINIT - 1024 ;