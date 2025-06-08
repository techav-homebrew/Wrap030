NEW
5 D$="................................................................................"
10 PRINT "Sinus (c) jbev 2022"
90 W=80
100 W=W/2:H=W-1
110 T=T+.125
115 I=I+1E-03
120 A=INT(W+H*SIN(T))
130 B=INT(W+H*COS(T*I))
140 IF A<B THEN L=A:R=B
150 IF A>B THEN L=B:R=A
155 IFA=B THEN L=A:M=0:R=0:GOTO 190
160 M=(L+R)/2
170 M=M-L
180 R=R-(M+L)
190 PRINT TAB(L);LEFT$(D$,M);"*";LEFT$(D$,R)
240 REM "IF INKEY$(1) <> "" THEN STOP"
260 IF I < .969 THEN 110
270 I=0:T=0:GOTO 110

