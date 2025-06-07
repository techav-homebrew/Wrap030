ramBot     = 0x00000000;
ramTop     = 0x00ffffff;
stackTop   = ramTop + 1;


MEMORY
{
    rom (rx)  : ORIGIN = 0x00000000, LENGTH = 0x00080000
    ram (rwx) : ORIGIN = 0x00080000, LENGTH = 0x01180000
}


acia1Com = 0x80080000;
acia1Dat = acia1Com + 4;
acia2Com = acia1Com + 8;
acia2Dat = acia2Com + 4;

overlayPort = 0x80180000;

timerBase = 0x80f00000;

romOffset           = 0x80000000;   /* position of ROM when overlay disabled */
romBot              = 0x00000000;
romTop              = 0x0001FFFF;
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

ioComBase   = 0x80300000;
ioCom0      = ioComBase + 0x0000 + 0x00;
ioCom1      = ioComBase + 0x0000 + 0x08;
ioCom2      = ioComBase + 0x0000 + 0x10;
ioCom3      = ioComBase + 0x0000 + 0x18;
ioCom4      = ioComBase + 0x0000 + 0x20;
ioCom5      = ioComBase + 0x0000 + 0x28;
ioCom6      = ioComBase + 0x0000 + 0x30;
ioCom7      = ioComBase + 0x0000 + 0x38;

uMemSize    = 1 * 1024 * 1024;
uMemSize0   = uMemSize;
uMemSize1   = uMemSize;
uMemSize2   = uMemSize;
uMemSize3   = uMemSize;
uMemSize4   = uMemSize;
uMemSize5   = uMemSize;
uMemSize6   = uMemSize;
uMemSize7   = uMemSize;

uFSbufSize  = 1 * 1024;
uFilBufSize = (512 * 1024) - uFSbufSize;

ENTRY(COLDBOOT)
SECTIONS{
    .vectors 0x00000000 :
    {
        VECTORS = .;
        Kernel/vectors.o (text)
        . = ALIGN(4);
    } > rom = 0xff
    .kernel 0x00001100 :
    {
        RESETENTRY = .;
        Kernel/boot.o (text)
        . = ALIGN(4);
        Kernel/kernel.o (text)
        . = ALIGN(4);
        libc/*.o (text)
        libff/*.o (text)
        wdisk/*.o (text)
    } > rom = 0xff
    .basic 0x00008000 :
    {
        ROMBASIC = . ;
        RAMBASIC = . ;
        .basicStart = . ;
        EhBASIC/ehbasic.o (text)
        .basicEnd = . ;
    } > rom = 0xff
    .kglobals 0x00010000 (NOLOAD) :
    {
        Kernel/vectors.o ( bss )
        Kernel/boot.o ( bss )
        Kernel/kernel.o ( bss )
        libc/*.o ( bss )
        libff/*.o ( bss )
        wdisk/*.o ( bss )
    } > ram
    .kusertable 0x00018000 (NOLOAD) :
    {
        USERTABLE = . ;
    } > ram
    .kmmutables 0x00020000 (NOLOAD) :
    {
        MMUTABLES = . ;
    } > ram
    .kmmutableu 0x00028000 (NOLOAD) :
    {
        MMUTABLEU = . ;
    } > ram
    .kstack 0x00070000 (NOLOAD):
    {
        STACKCRASH = .;
    }
    .kdiskbuf 0x00080000 (NOLOAD) :
    {
        STACKINIT = . ;
        DISKBUFU = . ;

        uFSBuf0 = . ;
        . += uFSbufSize;
        uFilBuf0 = .;
        . += uFilBufSize;
        uFSBuf1 = . ;
        . += uFSbufSize;
        uFilBuf1 = .;
        . += uFilBufSize;
        uFSBuf2 = . ;
        . += uFSbufSize;
        uFilBuf2 = .;
        . += uFilBufSize;
        uFSBuf3 = . ;
        . += uFSbufSize;
        uFilBuf3 = .;
        . += uFilBufSize;
        uFSBuf4 = . ;
        . += uFSbufSize;
        uFilBuf4 = .;
        . += uFilBufSize;
        uFSBuf5 = . ;
        . += uFSbufSize;
        uFilBuf5 = .;
        . += uFilBufSize;
        uFSBuf6 = . ;
        . += uFSbufSize;
        uFilBuf6 = .;
        . += uFilBufSize;
        uFSBuf7 = . ;
        . += uFSbufSize;
        uFilBuf7 = .;
        . += uFilBufSize;
    } > ram
    .usermem 0x00800000 (NOLOAD) :
    {
        
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

SIZEBASIC = .basicEnd - .basicStart ;
SUPVSTACKINIT = STACKINIT - 1024 ;
VECTORTABLE = VECTORS + romOffset ;
RESETVECTOR = RESETENTRY + romOffset ;

KTIMER = timerBase + 0x00003ffff ;
