
#include "spooler.h"
#include "syscalls.h"


void spoolEntry(){
    // C is stupid. there has to be a better way to do this
    tblUserBufPtr[0] = uBufStart0;
    tblUserBufPtr[1] = uBufStart1;
    tblUserBufPtr[2] = uBufStart2;
    tblUserBufPtr[3] = uBufStart3;
    tblUserBufPtr[4] = uBufStart4;
    tblUserBufPtr[5] = uBufStart5;
    tblUserBufPtr[6] = uBufStart6;
    tblUserBufPtr[7] = uBufStart7;

    spoolUser = 0;
    // initialize user tables
    for(int i=0; i<MAXUSERS; i++){
        spoolUserReset(i);
    }
    while(1){
        spoolMain();
    }
}

void spoolMain(){
    for(int i=0; i<MAXUSERS; i++){
        if(spoolTable[i].sTblFlags & flagJobReady){
            spoolPrint(i);
        }
    }
    cTrapYield();
}

void spoolPrint(unsigned int user){
    char * head = spoolTable[user].sTblHead;
    char * tail = spoolTable[user].sTblTail;
    while(head < tail){
        cTrapConWrite(*head++);
    }
}

void spoolUserReset(unsigned int user){
    spoolTable[user].sTblHead = tblUserBufPtr[user];
    spoolTable[user].sTblTail = tblUserBufPtr[user];
    spoolTable[user].sTblFlags = 0;
}
