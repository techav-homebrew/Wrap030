

#include "../libff/ff.h"
#include "acia.h"

#ifndef wrap030boot_h
#define wrap030boot_h

FATFS fs;

// load BOOT.BIN from disk to RAM address 0
unsigned char LoadBootBin();

#endif