
// constants
#define MAXUSERS 8
#define STACKSIZE 512

#define flagJobReady (1 << 0)

extern char * const uBufStart0;
extern char * const uBufStart1;
extern char * const uBufStart2;
extern char * const uBufStart3;
extern char * const uBufStart4;
extern char * const uBufStart5;
extern char * const uBufStart6;
extern char * const uBufStart7;
extern const int uSpoolSize;


// definitions
struct sTbl {
    char * sTblHead;
    char * sTblTail;
    unsigned int sTblFlags;
};

// global variables
char * tblUserBufPtr[MAXUSERS];

struct sTbl spoolTable[MAXUSERS];

unsigned int spoolUser;

// function primitives
void spoolEntry();

void spoolMain();

void spoolPrint(unsigned int);

void spoolUserReset(unsigned int);
