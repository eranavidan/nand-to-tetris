// Mult.asm
// Author:  Nick Platt <platt.nicholas@gmail.com>
// License: MIT <http://opensource.org/licenses/MIT>

@R2            // Zero-out output register
M=0            //

@R0            // Boundary test: R0 > 0
D=M            //
@END           //
D;JEQ          //

@R1            // Boundary test: R1 > 0
D=M            //
@END           //
D;JEQ          //

(LOOP)
   @R0         // R0 into data register
   D=M         //

   @R2         // R2 += D
   M=M+D       //

   @R1         // R1 -= 1
   M=M-1       //

   D=M         // Loop while D > 0
   @LOOP       //
   D;JGT       //

(END)
