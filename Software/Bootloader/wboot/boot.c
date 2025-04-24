

#include "boot.h"

unsigned char LoadBootBin()
{
    FIL bootFile;
    FRESULT fileResult;
    unsigned int bytesRead;
    BYTE* fileBuffer = 0;
    printStrLn("");
    #ifdef DEBUG
    printStrLn("\t*LOADBOOTBIN* Debug enabled ... ");
    #endif

    // initialize external data
    printStrLn("\tInitializing filesystem driver ... ");
    f_initialize();

    // mount file system
    printStrLn("\tMounting ... ");
    f_mount(&fs,"",0);

    // open file BOOT.BIN
    printStrLn("\tOpening BOOT.BIN ... ");
    fileResult = f_open(&bootFile,"BOOT.BIN",FA_READ);
    #ifdef DEBUG
    printStr("Result: 0x");
    printHexByte((BYTE)fileResult);
    printStr(" ... ");
    #endif
    if(fileResult) return (unsigned char)fileResult;

    // read all of BOOT.BIN file
    printStrLn("\tReading ... ");
    fileResult = f_read(&bootFile, fileBuffer, -1, &bytesRead);

    // close file & unmount
    printStrLn("\tClosing ... ");
    f_close(&bootFile);
    f_unmount("");

    printStrLn("\tDone ... ");
    return (unsigned char)fileResult;
}
