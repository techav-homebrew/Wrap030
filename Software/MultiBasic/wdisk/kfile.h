#include "../libff/ff.h"

#ifndef KFILE_H
#define KFILE_H

FATFS fs;
FIL usrFile[8];

FRESULT diskInit();

DIR dirPtr[8];

#endif