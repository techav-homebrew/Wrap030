ramBot     = 0x00000000;
ramTop     = 0x00ffffff;
stackTop   = ramTop + 1;

/*
romSector0 = 0x00200000;
romSector1 = 0x00210000;
*/

MEMORY
{
    ram (rwx) : ORIGIN = 0x00000000, LENGTH = 0x00100000
}

acia1Com = 0x80080000;
acia1Dat = acia1Com + 4;
acia2Com = acia1Com + 8;
acia2Dat = acia2Com + 4;

overlayPort = 0x80180000;
/*
romBot              = 0x00200000;
romTop              = 0x0021FFFF;
*/

romOffset           = 0x80000000;   /* position of ROM when overlay disabled */
romBot              = 0x00000000;
romTop              = 0x0001FFFF;
romSector0          = romBot;
romSector1          = romBot + 0x00010000;

timerBase           = 0x80f00000;

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

uMemSize    = 128 * 1024;
uMemSize0   = uMemSize;
uMemSize1   = uMemSize;
uMemSize2   = uMemSize;
uMemSize3   = uMemSize;
uMemSize4   = uMemSize;
uMemSize5   = uMemSize;
uMemSize6   = uMemSize;
uMemSize7   = uMemSize;

ENTRY(WARMBOOT)
SECTIONS{
    .vectors 0x00000000 :
    {
        VECTORS = .;
        TimerTest/vectors.o (text)
        . = ALIGN(4);
        TimerTest/TimerTest.o (text)
        . = ALIGN(4096);
        TimerTest/*.o (bss)
    } > ram
}

