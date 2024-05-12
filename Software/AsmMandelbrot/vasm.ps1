# ..\..\Utilities\vasm\vasmm68k_mot.exe -Felf -L AsmMandelbrot.L68 -o AsmMandelbrot.elf -m68030 -m68882 AsmMandelbrot.x68
# m68k-elf-ld -A 68030 -T linker.ld -s -M -n -static -o AsmMandelbrot.BIN AsmMandelbrot.elf

# assemble to S-Record
..\..\Utilities\vasm\vasmm68k_mot.exe -Fsrec -L AsmMandelbrot.L68 -o AsmMandelbrot.S68 -m68030 -m68882 -s28 -exec=start AsmMandelbrot.x68

# assemble to simple binary
..\..\Utilities\vasm\vasmm68k_mot.exe -Fbin -L AsmMandelbrot.L68 -o MNDLBRT1.BIN -m68030 -m68882 -exec=start AsmMandelbrot.x68