

#include "../libff/ff.h"
#include "../libff/diskio.h"
#include "wdisk.h"

#include "../wboot/acia.h"

DSTATUS wrap030_disk_status(BYTE pdrive)
{
    BYTE status;
    #ifdef DEBUG
    printStrLn("*WRAP030_DISK_STATUS*");
    #endif
    if(pdrive > 0) return STA_NOINIT;
    status = ideStatusRO;
    if(status == 0) return STA_NODISK;
    else return 0;
}

DSTATUS wrap030_disk_initialize(BYTE pdrive)
{
    #ifdef DEBUG
    printStrLn("*WRAP030_DISK_INITIALIZE*");
    #endif
    if(pdrive > 0) return STA_NOINIT;
    else return 0;
}


int wrap030_disk_read(BYTE pdrive, BYTE *buff, LBA_t sector, UINT count)
{
    uint32_t lba;
    BYTE disk_status;
    uint32_t timeoutCounter;

    #ifdef DEBUG
    int debugCount = 0;
    printStr("*WRAP030_DISK_READ* pdrive: ");
    printHexByte(pdrive);
    printStr(" buffer 0x");
    printHexLong((int)buff);
    printStr(" LBA 0x");
    printHexLong(sector);
    printStr(" count ");
    printHexByte(count);
    printStr("\r\n");
    #endif

    if(pdrive > 0) return WDISK_DNE;
    if(count == 0 || count > 255) return WDISK_PARERR;

    // make sure disk isn't busy before continuing
    #ifdef DEBUG
    printStrLn("*WRAP030_DISK_READ* waiting for disk not busy ... ");
    #endif
    timeoutCounter = DISKTIMEOUT;
    while(wrap030_disk_busy())
    {
        if(--timeoutCounter == 0) return WDISK_BUSY;
    }

    #ifdef DEBUG
    printStrLn("*WRAP030_DISK_READ* writing parameters to disk registers ...");
    #endif
    // mask 28-bit LBA and set LBA mode flag
    lba = ((uint32_t)sector & 0x0fffffff) | 0xe0000000;

    // send LBA to drive
    ideLBALLRW = (BYTE)(lba & 0xff);
    ideLBALHRW = (BYTE)((lba >> 8) & 0xff);
    ideLBAHLRW = (BYTE)((lba >> 16) & 0xff);
    ideLBAHHRW = (BYTE)((lba >> 24) & 0xff);

    // send sector count to drive
    ideSectorCountRW = count;

    // send read sectors command to drive
    ideCommandWO = 0x20;

    // read disk
    #ifdef DEBUG
    printStrLn("*WRAP030_DISK_READ* entering read loop ...");
    #endif
    while(count--)
    {
        // wait for data ready
        #ifdef DEBUG
        printStrLn("*WRAP030_DISK_READ* waiting for data ready ...");
        #endif
        timeoutCounter = DISKTIMEOUT;
        while(!wrap030_disk_read_ready())
        {
            if(--timeoutCounter == 0) return WDISK_NRDY;
        }

        // read sector
        for(int i=256; i>0; i--)
        {
            WORD dat = ideDataRW;

            #ifdef DEBUG
            if(!(debugCount & 0x0f))
            {
                printStr("\r\n");
            }
            debugCount++;
            printHexWord(dat);
            printStr(" ");
            #endif
            
            *buff++ = (BYTE)((dat >> 8) & 0x00ff);
            *buff++ = (BYTE)(dat & 0x00ff);
        }
        #ifdef DEBUG
        printStr("\r\n");
        #endif
    }
    #ifdef DEBUG
    printStrLn("*WRAP030_DISK_READ* read complete.");
    #endif
    return WDISK_OK;
}




// DSTATUS wrap030_disk_read(BYTE pdrive, BYTE *buff, LBA_t sector, UINT count)
// {
//     uint32_t lba;
//     BYTE disk_status;
//     #ifdef DEBUG
//     int debugCount = 0;
//     printStr("*WRAP030_DISK_READ* pdrive: ");
//     printHexByte(pdrive);
//     printStr(" buffer 0x");
//     printHexLong((int)buff);
//     printStr(" LBA 0x");
//     printHexLong(sector);
//     printStr(" count ");
//     printHexByte(count);
//     printStr("\r\n");
//     #endif
//     if(pdrive > 0) 
//     {
//         #ifdef DEBUG
//         printStrLn("*WRAP030_DISK_READ* bad disk number (pdrive>0)");
//         #endif
//         return RES_NOTRDY;
//     }
//     if(count == 0 || count > 255) 
//     {
//         #ifdef DEBUG
//         printStr("*WRAP030_DISK_READ* bad sector count: 0x");
//         printHexByte(count);
//         printStrLn("");
//         #endif
//         return RES_PARERR;
//     }

//     #ifdef DEBUG
//     printStrLn("*WRAP030_DISK_READ* waiting for disk not busy ... ");
//     #endif
//     while(wrap030_disk_busy());

//     #ifdef DEBUG
//     printStrLn("*WRAP030_DISK_READ* writing parameters to disk registers ...");
//     #endif
//     // mask 28-bit LBA and set LBA mode flag
//     lba = ((uint32_t)sector & 0x0fffffff) | 0xe0000000;

//     // send LBA to drive
//     ideLBALLRW = (BYTE)(lba & 0xff);
//     ideLBALHRW = (BYTE)((lba >> 8) & 0xff);
//     ideLBAHLRW = (BYTE)((lba >> 16) & 0xff);
//     ideLBAHHRW = (BYTE)((lba >> 24) & 0xff);

//     // send sector count to drive
//     ideSectorCountRW = count;

//     // send read sectors command to drive
//     ideCommandWO = 0x20;

//     #ifdef DEBUG
//     printStrLn("*WRAP030_DISK_READ* entering read loop ...");
//     #endif
//     while(count--)
//     {
//         if(wrap030_wait_for_disk_read_ready() != 1) 
//         {
//             #ifdef DEBUG
//             printStrLn("*WRAP030_DISK_READ* error waiting for disk.");
//             #endif
//             return RES_ERROR;
//         }
//         for(int i=256; i>0; i--)
//         {
//             WORD dat = ideDataRW;
//             #ifdef DEBUG
//             if(!(debugCount & 0x0f))
//             {
//                 printStr("\r\n");
//             }
//             debugCount++;
//             printHexWord(dat);
//             printStr(" ");
//             #endif
//             *buff++ = (BYTE)(dat & 0x00ff);
//             *buff++ = (BYTE)((dat >> 8) & 0x00ff);
//         }
//     }

//     #ifdef DEBUG
//     printStrLn("\r\n*WRAP030_DISK_READ* Read sector complete.");
//     #endif
//     return RES_OK;
// }


#if FF_FS_READONLY == 0
DRESULT wrap030_disk_write(BYTE pdrive, const BYTE *buff, LBA_t sector, UINT count)
{
    //
}
#endif

DRESULT wrap030_disk_ioctl(BYTE pdrive, BYTE cmd, void *buff)
{
    #ifdef DEBUG
    printStrLn("*WRAP030_DISK_IOCTL*");
    #endif
    switch (cmd)
    {
    case CTRL_SYNC:
        return RES_OK;
        break;
    case GET_SECTOR_SIZE:
        *((WORD*)buff) = 512;
        return RES_OK;
        break;
    case GET_BLOCK_SIZE:
        *((DWORD*)buff) = 1;
        return RES_OK;
        break;
    case CTRL_TRIM:
        return RES_OK;
        break;
    default:
        return RES_PARERR;
        break;
    }
}

// returns 1 if busy
// returns 0 if not busy
BYTE wrap030_disk_busy()
{
    BYTE status = ideStatusRO;
    if(status & IDE_STATUS_BSY) return 1;
    else return 0;
}

// returns 1 if ready
// returns 0 if not ready
// returns <0 on error
BYTE wrap030_disk_read_ready()
{
    BYTE status = ideStatusRO;
    if(status & IDE_STATUS_BSY) return 0;
    else if(!(status & IDE_STATUS_DRDY)) return 0;
    //else if(!(status & IDE_STATUS_DRQ)) return 0;
    else if(status & IDE_STATUS_ERR) return -1;
    else return 1;
}

// wait for disk ready, with timeout
// returns 1 if ready
// returns -1 on error
// returns 0 on timeout;
BYTE wrap030_wait_for_disk_read_ready()
{
    BYTE ready = 0;
    for(uint32_t i=DISKTIMEOUT; i>0; i--)
    {
        BYTE status = wrap030_disk_read_ready();
        //if(status != 0) return status;
        if(status != 0)
        {
            if(status < 0) 
            {
                #ifdef DEBUG
                printStr("WDISK: disk reported error ... ");
                #endif
            }
            return status;
        }
    }
    #ifdef DEBUG
    printStr("WDISK: timeout waiting for disk ready ... ");
    #endif
    return 0;
}