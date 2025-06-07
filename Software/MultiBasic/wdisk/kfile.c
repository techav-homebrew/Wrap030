#include "kfile.h"
#include "acia.h"

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