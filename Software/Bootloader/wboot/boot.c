

#include "boot.h"

unsigned char LoadBootBin()
{
    FIL bootFile;
    FRESULT fileResult;
    unsigned int bytesRead;
    BYTE* fileBuffer = 0;

    // mount file system
    printStr("\r\n\tMounting ... ");
    f_mount(&fs,"",0);

    // open file BOOT.BIN
    printStr("\r\b\tOpening BOOT.BIN ... ");
    fileResult = f_open(&bootFile,"BOOT.BIN",FA_READ);
    if(fileResult) return (unsigned char)fileResult;

    // read all of BOOT.BIN file
    printStr("\r\n\tReading ... ");
    fileResult = f_read(&bootFile, fileBuffer, -1, &bytesRead);

    // close file & unmount
    printStr("\r\n\tClosing ... ");
    f_close(&bootFile);
    f_unmount("");

    printStr("\r\n\tDone ... ");
    return (unsigned char)fileResult;
}
