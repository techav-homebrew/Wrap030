
#include "acia.h"

void printChr(char c)
{
    if(!c) return;
    while(!(acia1Com & statTDRE));
    acia1Dat = c;
}

void printStr(char * str)
{
    char c = *str++;
    while(c)
    {
        // wait for tx ready
        while((acia1Com & statTDRE) == 0);
        // print c
        acia1Dat = c;
        c = *str++;
    }
}

void printStrLn(char * str)
{
    printStr(str);
    printStr("\r\n");
}

void printHexByte(unsigned char c)
{
    unsigned char d;
    d = (c >> 4) & 0x0f;
    d += (d<10) ? 0x30 : 0x37;
    printChr(d);
    d = (c & 0x0f);
    d += (d<10) ? 0x30 : 0x37;
    printChr(d);
}
void printHexWord(unsigned short w)
{
    unsigned short x;
    x = (w >> 8) & 0x00ff;
    printHexByte(x);
    printHexByte(w);
}
void printHexLong(unsigned int l)
{
    unsigned int m;
    m = (l >> 16);
    printHexWord(m);
    printHexWord(l);
}
