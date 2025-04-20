

#include "boot.h"


unsigned char LoadBootBin()
{
    FIL bootFile;
    FRESULT fileResult;
    unsigned int bytesRead;
    BYTE* fileBuffer = 0;

    // mount file system
    f_mount(&fs,"",0);

    // open file BOOT.BIN
    fileResult = f_open(&bootFile,"BOOT.BIN",FA_READ);
    if(fileResult) return (unsigned char)fileResult;

    // read all of BOOT.BIN file
    fileResult = f_read(&bootFile, fileBuffer, -1, &bytesRead);

    // close file & unmount
    f_close(&bootFile);
    f_unmount("");

    return (unsigned char)fileResult;
}
