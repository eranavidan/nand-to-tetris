// Fill.asm
// Author:  Nick Platt <platt.nicholas@gmail.com>
// License: MIT <http://opensource.org/licenses/MIT>

//////////////////////////////////////////////////
(MAIN)
   @KBD
   D=M

   @KBD_ACTIVE
   D;JGT

   @KBD_NULL
   D;JEQ

   @MAIN
   0;JMP
//////////////////////////////////////////////////

//////////////////////////////////////////////////
(KBD_ACTIVE)
   @SCREEN     // Jump to MAIN if value at SCREEN
   D=M         //   is positive (filled)
   @MAIN       //
   D;JGT       //

   @0          // Store fill value of 111...
   D=!A        //
   @R0         //
   M=D         //

   @PAINT
   0;JMP
//////////////////////////////////////////////////

//////////////////////////////////////////////////
(KBD_NULL)
   @SCREEN     // Jump to MAIN if value at SCREEN
   D=M         //   is zero (clear)
   @MAIN       //
   D;JEQ       //

   @R0         // Store fill value of 000...
   M=0         //

   @PAINT
   0;JMP
//////////////////////////////////////////////////

//////////////////////////////////////////////////
(PAINT)
   @SCREEN     // Initialize word pointer to SCREEN
   D=A         //
   @R1         //
   M=D         //

   (LOOP)
      @R0      // Load the fill value (111... or 000...)
      D=M      //

      @R1      // Load the next word to write to
      A=M      //

      M=D      // Write fill value to the word

      @R1      // Increment next word pointer
      M=M+1    //

      D=M      // Store next word pointer

      @24576   // (256 rows * 32 words wide) + SCREEN
      D=D-A    // Jump to LOOP until next word pointer
      @LOOP    //   equals our constant marking the end
      D;JLT    //   of SCREEN (note: @24576 == @KBD)

   @MAIN
   0;JMP
//////////////////////////////////////////////////
