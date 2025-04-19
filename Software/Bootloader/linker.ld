
/* 
 * define 128kB ROM region at address $8000,0000
 * define 16MB RAM region at address $0000,0000
 */
ramBot      = 0x00000000;
ramTop      = 0x00ffffff;
romBot      = 0x00000000;
romTop      = 0x0001ffff;
romOffset   = 0x80000000;

MEMORY
{
    rom (rx)  : ORIGIN = 0x00000000, LENGTH = 0x00080000
    ram (rwx) : ORIGIN = 0x00080000, LENGTH = 0x01180000
}

/* startup overlay port */
overlayPort = 0x80180000;

/* main-board UART */
acia1Com = 0x80080000;
acia1Dat = acia1Com + 4;

/* mezzanine board IDE */
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

ENTRY(COLDBOOT)
SECTIONS{
    .vectors 0x00000000 :
    {
        VECTORS = .;
        wboot/vectors.o (text)
        . = ALIGN(4);
    } > rom = 0xff
    .bootloader 0x00001000 :
    {
        RESETENTRY = .;
        wboot/bootloader.o (text)
        . = ALIGN(4);
        wboot/boot.o (text)
        libc/*.o (text)
        libff/*.o (text)
    } > rom = 0xff
}

/*
 * Initial interrupt stack pointer is a **ROM** address, not RAM. 
 * This is intentional. If the RAM card is not present or malfunctioning,
 * the system will double-bus-fault and halt on any exception, preventing
 * any printout of what the error may have been. Write protection on the 
 * flash chip will prevent actually overwriting the ROM code without a 
 * special write sequence, so if there is an exception, exception stack frame
 * will just be lost instead of a double-bus-fault. 
 */
STACKINIT = romTop + 1 + 0x00020000 ;

/* 
 * These stack pointers are at the top of RAM and should be initialized after
 * memory has been initialized and verified.
 */
IRQSTACKINIT = ramTop + 1;
SUPVSTACKINIT = ramTop + 1 - 1024;

VECTORTABLE = VECTORS + romOffset ;
RESETVECTOR = RESETENTRY + romOffset ;
