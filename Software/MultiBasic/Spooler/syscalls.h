
extern inline __attribute__((always_inline)) void cTrapYield(){
    __asm__ volatile (
        "moveq #0,%%d1\n\t"
        "trap #0\n\t"
        :
        :
        : "%d1"
    );
}

extern inline __attribute__((always_inline)) char cTrapConRead(){
    register char r __asm__ ("%d0");
    __asm__ volatile (
        "moveq #1,%%d1\n\t"
        "trap #0\n\t"
        : "=r" (r)
        :
        : "%d1"
    );
}

extern inline __attribute__((always_inline)) void cTrapConWrite(char c){
    register char chr __asm__ ("%d0") = c;
    __asm__ volatile (
        "moveq  #2,%%d1\n\t"
        "trap   #0\n\t"
        :
        : "r" (chr)
        : "%d1"
    );
}