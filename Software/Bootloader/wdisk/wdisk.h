#include "../libff/ff.h"
#include "../libff/diskio.h"

#ifndef WRAP030_DISK_H
#define WRAP030_DISK_H


#define DISKTIMEOUT 0x00007fff

#define IDE_STATUS_BSY (1 << 7)
#define IDE_STATUS_DRDY (1 << 6)
#define IDE_STATUS_DWF (1 << 5)
#define IDE_STATUS_DSC (1 << 4)
#define IDE_STATUS_DRQ (1 << 3)
#define IDE_STATUS_CORR (1 << 2)
#define IDE_STATUS_IDX (1 << 1)
#define IDE_STATUS_ERR (1 << 0)

extern WORD volatile * const ideDataRW;
extern BYTE const volatile * const ideErrorRO;
extern BYTE volatile *const ideFeatureWO;
extern BYTE volatile *const ideSectorCountRW;
extern BYTE volatile *const ideLBALLRW;
extern BYTE volatile *const ideLBALHRW;
extern BYTE volatile *const ideLBAHLRW;
extern BYTE volatile *const ideLBAHHRW;
extern BYTE const volatile * const ideStatusRO;
extern BYTE volatile *const ideCommandWO;
extern BYTE const volatile * const ideAltStatusRO;
extern BYTE volatile *const ideDevControlWO;
extern BYTE const volatile * const ideDevAddressRO;

DSTATUS wrap030_disk_status(BYTE);
DSTATUS wrap030_disk_initialize(BYTE);
DSTATUS wrap030_disk_read(BYTE,BYTE*,LBA_t,UINT);

#if FF_FS_READONLY == 0
DRESULT wrap030_disk_write(BYTE, const BYTE*, LBA_t, UINT);
#endif

DRESULT wrap030_disk_ioctl(BYTE, BYTE, void*);

BYTE wrap030_disk_read_ready();
BYTE wrap030_wait_for_disk_read_ready();

#endif
