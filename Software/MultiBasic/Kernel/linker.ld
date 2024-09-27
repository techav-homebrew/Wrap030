ramBot     = 0x00000000;
ramTop     = 0x001fffff;
stackTop   = ramTop + 1;
romSector0 = 0x00200000;
romSector1 = 0x00210000;

MEMORY
{
    ram (rwx) : ORIGIN = 0x00000000, LENGTH = 0x00200000
    rom (rx)  : ORIGIN = 0x00200000, LENGTH = 0x00020000
}

acia1Com = 0x00380000;
acia1Dat = acia1Com + 4;
acia2Com = acia1Com + 8;
acia2Dat = acia2Com + 4;

overlayPort = 0x00300000;
romTop   = 0x0021FFFF;

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

io8base     = 0x80000000;
io8card0    = io8base;
io8card1    = io8base + 0x002000;
io8card2    = io8base + 0x004000;
io8card3    = io8base + 0x006000;
io8card4    = io8base + 0x008000;
io8card5    = io8base + 0x00a000;
io8card6    = io8base + 0x00c000;
io8card7    = io8base + 0x00e000;

ioCom0      = io8card0 + 0x0000 + 0x00;
ioCom1      = io8card0 + 0x0000 + 0x08;
ioCom2      = io8card0 + 0x0000 + 0x10;
ioCom3      = io8card0 + 0x0000 + 0x18;
ioCom4      = io8card0 + 0x0800 + 0x00;
ioCom5      = io8card0 + 0x0800 + 0x08;
ioCom6      = io8card0 + 0x0800 + 0x10;
ioCom7      = io8card0 + 0x0800 + 0x18;

uMemSize    = 128 * 1024;
uMemSize0   = uMemSize;
uMemSize1   = uMemSize;
uMemSize2   = uMemSize;
uMemSize3   = uMemSize;
uMemSize4   = uMemSize;
uMemSize5   = uMemSize;
uMemSize6   = uMemSize;
uMemSize7   = uMemSize;

uMemStart   = 0x00100000;
uMemStart0  = uMemStart;
uMemStart1  = uMemStart0 + uMemSize;
uMemStart2  = uMemStart1 + uMemSize;
uMemStart3  = uMemStart2 + uMemSize;
uMemStart4  = uMemStart3 + uMemSize;
uMemStart5  = uMemStart4 + uMemSize;
uMemStart6  = uMemStart5 + uMemSize;
uMemStart7  = uMemStart6 + uMemSize;


ENTRY(_cold)
SECTIONS{
    .kernel 0x00200000 :
    {
        vectors.o ( text )
        boot.o ( text )
        kernel.o ( text )
    } > rom = 0xff
    .bss 0x400 (NOLOAD) :
    {
        ramStart = . ;
        kernel.o ( bss )
    } > ram
    /DISCARD/ :
    {
        *( .comment )
    }
}