
#ifndef ACIA_H
#define ACIA_H

#define statRDRF (1 << 0)
#define statTDRE (1 << 1)
#define statDCD  (1 << 2)
#define statCTS  (1 << 3)
#define statFE   (1 << 4)
#define statOVRN (1 << 5)
#define statPE   (1 << 6)
#define statIRQ  (1 << 7)

extern unsigned char volatile acia1Com;
extern unsigned char volatile acia1Dat;

void printChr(char);
void printStr(char *);
void printStrLn(char *);

void printHexByte(unsigned char);
void printHexWord(unsigned short);
void printHexLong(unsigned int);

#endif
