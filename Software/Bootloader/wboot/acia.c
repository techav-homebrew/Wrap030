
#include "acia.h"

void printStr(char * str)
{
    char c;
    c = *str++;
    while(c)
    {
        // wait for tx ready
        while((*acia1Com & statTDRE) == 0);
        // print c
        *acia1Dat = c;
    }
}
