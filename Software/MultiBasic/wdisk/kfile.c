#include "kfile.h"
#include "acia.h"
#include "../libc/string.h"

FRESULT diskInit()
{
    FRESULT res;

    printStr("Initializing file system ... ");
    f_initialize();
    printStrLn("OK");

    printStr("Mounting disk ... ");
    res = f_mount(&fs,"",0);
    if(res)
    {
        printStr("FAILED: ");
        printHexByte(res);
        printStrLn("");
    }
    else
    {
        printStrLn("OK");
    }

    return res;
}


/* wrapper functions for the corresponding sysTraps */
FRESULT openDir(int User)
{
    FRESULT res;
#ifdef DEBUG
    printStr("*OPENDIR* User: 0x");
    printHexByte((char)User);
    printStrLn("");
#endif
    res = f_opendir(&dirPtr[User], "/");
#ifdef DEBUG
    printStr("*OPENDIR* returning: 0x");
    printHexByte(res);
    printStrLn("");
#endif
    return res;
}

FRESULT readDir(int User, TCHAR * fileName)
{
    FILINFO fno;
    FRESULT res;

#ifdef DEBUG
    printStrLn("*READDIR*");
    printStr("*READDIR* fileName: (");
    printHexLong((int)fileName);
    printStrLn(")");
#endif

    res = f_readdir(&dirPtr[User], &fno);
    /* if(res == FR_OK && fno.fname[0] != 0 && !(fno.fattrib & AM_DIR)) */
    if(res == FR_OK && fno.fname[0] != 0)
    {
        memcpy(fileName, fno.fname, sizeof(fno.fname));
#ifdef DEBUG
        printStr("*READDIR* rx: ");
        printStr(fno.fname);
        printStr(" tx: ");
        printStrLn(fileName);
#endif
    }
    else
    {
        fileName[0] = 0;
    }
#ifdef DEBUG
    printStr("*READDIR* returning: ");
    printHexByte(res);
    printStrLn("");
#endif
    return res;
}

FRESULT closeDir(int User)
{
#ifdef DEBUG
    printStr("*CLOSEDIR* User: 0x");
    printHexByte((char)User);
    printStrLn("");
#endif
    return f_closedir(&dirPtr[User]);
}