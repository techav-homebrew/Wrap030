NEW
5 E=30
10 C=40
20 FOR A=0 TO 6.2 STEP 0.2
30 B=C+SIN(A)*E
40 F=C+COS(A)*E
50 FOR D=0 TO B
60 PRINT "|";
70 NEXT D
80 IF F<=B THEN GOTO 150
90 FOR G=0 TO (F-B)
100 PRINT "-";
110 NEXT G
150 PRINT
160 NEXT A
200 GOTO 20
