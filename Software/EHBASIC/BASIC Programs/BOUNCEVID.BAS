10 CALL $26000C $00
20 X=0:Y=0
30 X1=0:Y1=0
40 A=0:B=0
50 CALL $26001C X,Y,$4F
60 CALL $26001C X1,Y1,$20
70 CALL $26001C X1,Y1,$20
80 X1=X:Y1=Y
90 X=X+A:Y=Y+B
100 IF X>=63 THEN A=-1
110 IF Y>=41 THEN B=-1
120 IF X<=0 THEN A=1
130 IF Y<=0 THEN B=1
140 FOR I=0 TO 250
150 NEXT I
160 GOTO 50
