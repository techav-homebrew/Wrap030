

#include "../libff/ff.h"
#include "../libff/diskio.h"
#include "wdisk.h"



DSTATUS wrap030_disk_status(BYTE pdrive)
{
    BYTE status;
    if(pdrive > 0) return STA_NOINIT;
    status = *ideStatusRO;
    if(status == 0) return STA_NODISK;
    else return 0;
}

DSTATUS wrap030_disk_initialize(BYTE pdrive)
{
    if(pdrive > 0) return STA_NOINIT;
    else return 0;
}

DSTATUS wrap030_disk_read(BYTE pdrive, BYTE *buff, LBA_t sector, UINT count)
{
    uint32_t lba;
    BYTE disk_status;
    if(pdrive > 0) return RES_NOTRDY;
    if(count == 0 || count > 255) return RES_PARERR;

    // mask 28-bit LBA and set LBA mode flag
    lba = ((uint32_t)sector & 0x0fffffff) | 0xe0000000;

    // send LBA to drive
    *ideLBALLRW = (BYTE)(lba & 0xff);
    *ideLBALHRW = (BYTE)((lba >> 8) & 0xff);
    *ideLBAHLRW = (BYTE)((lba >> 16) & 0xff);
    *ideLBAHHRW = (BYTE)((lba >> 24) & 0xff);

    // send sector count to drive
    *ideSectorCountRW = count;

    // send read sectors command to drive
    *ideCommandWO = 0x20;

    while(--count)
    {
        if(wrap030_wait_for_disk_read_ready() != 1) return RES_ERROR;
        for(int i=255; i>0; i--)
        {
            WORD dat = *ideDataRW;
            *buff++ = (BYTE)(dat & 0x00ff);
            *buff++ = (BYTE)((dat >> 8) & 0x00ff);
        }
    }
    return RES_OK;
}

#if FF_FS_READONLY == 0
DRESULT wrap030_disk_write(BYTE pdrive, const BYTE *buff, LBA_t sector, UINT count)
{
    //
}
#endif

DRESULT wrap030_disk_ioctl(BYTE pdrive, BYTE cmd, void *buff)
{
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


// returns 1 if ready
// returns 0 if not ready
// returns <0 on error
BYTE wrap030_disk_read_ready()
{
    BYTE status = *ideStatusRO;
    if(status & IDE_STATUS_BSY) return 0;
    else if(!(status & IDE_STATUS_DRDY)) return 0;
    else if(!(status & IDE_STATUS_DRQ)) return 0;
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
        if(status != 0) return status;
    }
    return 0;
}