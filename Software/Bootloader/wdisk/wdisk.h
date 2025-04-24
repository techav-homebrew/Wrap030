#include "../libff/ff.h"
#include "../libff/diskio.h"

#ifndef WRAP030_DISK_H
#define WRAP030_DISK_H


#define DISKTIMEOUT 0x00007fff
#define RETRYCOUNT 10


#define WDISK_DNE       -1  /* disk does not exist */
#define WDISK_PARERR    -2  /* bad parameter*/
#define WDISK_BUSY      -3  /* disk busy timeout */
#define WDISK_ERROR     -4  /* disk reported an error */
#define WDISK_NRDY      -5  /* disk not ready timeout */
#define WDISK_OK         0  /* status good */


#define IDE_STATUS_BSY (1 << 7)
#define IDE_STATUS_DRDY (1 << 6)
#define IDE_STATUS_DWF (1 << 5)
#define IDE_STATUS_DSC (1 << 4)
#define IDE_STATUS_DRQ (1 << 3)
#define IDE_STATUS_CORR (1 << 2)
#define IDE_STATUS_IDX (1 << 1)
#define IDE_STATUS_ERR (1 << 0)

extern WORD volatile ideDataRW;
extern BYTE const volatile ideErrorRO;
extern BYTE volatile ideFeatureWO;
extern BYTE volatile ideSectorCountRW;
extern BYTE volatile ideLBALLRW;
extern BYTE volatile ideLBALHRW;
extern BYTE volatile ideLBAHLRW;
extern BYTE volatile ideLBAHHRW;
extern BYTE const volatile ideStatusRO;
extern BYTE volatile ideCommandWO;
extern BYTE const volatile ideAltStatusRO;
extern BYTE volatile ideDevControlWO;
extern BYTE const volatile ideDevAddressRO;

DSTATUS wrap030_disk_status(BYTE);
DSTATUS wrap030_disk_initialize(BYTE);
int wrap030_disk_read(BYTE,BYTE*,LBA_t,UINT);

#if FF_FS_READONLY == 0
DRESULT wrap030_disk_write(BYTE, const BYTE*, LBA_t, UINT);
#endif

DRESULT wrap030_disk_ioctl(BYTE, BYTE, void*);

BYTE wrap030_disk_busy();
BYTE wrap030_disk_read_ready();
BYTE wrap030_wait_for_disk_read_ready();

#endif
