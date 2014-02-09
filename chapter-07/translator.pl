#!/usr/bin/perl
# translator.pl
# Author:  Nick Platt <platt.nicholas@gmail.com>
# License: MIT <http://opensource.org/licenses/MIT>

use strict;
use warnings;
no warnings 'uninitialized';

die 'Usage: translator.pl [ <file> | <directory> ]' unless $ARGV[0];

package main;
   my $translator = Translator->new;
   $translator->init;
   $translator->load_file($ARGV[0]);
   $translator->translate;


package Translator;
   sub new { return bless {}, shift; }

   sub init {
      my $self = shift;

      $self->{parser} = Parser->new;
      $self->{writer} = Writer->new;
   }

   sub load_file {
      my ($self, $file) = @_;

      open(my $fh, '<', $file) or die "Unable to open $file";
      $self->{parser}->load_file($fh);

      $self->{writer}->init($file);
   }

   sub translate {
      my $self = shift;

      while ($self->{parser}->can_advance) {
         $self->{parser}->advance;

         if ($self->{parser}->command_type eq 'C_ARITHMETIC') {
            $self->{writer}->write_arithmetic($self->{parser}->arg1);
         }
         elsif (   $self->{parser}->command_type eq 'C_PUSH'
                || $self->{parser}->command_type eq 'C_POP') {
            $self->{writer}->write_push_pop(
               $self->{parser}->command_type,
               $self->{parser}->arg1,
               $self->{parser}->arg2
            );
         }
      }
   }


package Parser;
   sub new { return bless {}, shift; }

   sub load_file {
      my ($self, $fh) = @_;
      $self->{fh} = $fh;
   }

   sub can_advance {
      my $self = shift;
      return !eof($self->{fh});
   }

   sub advance {
      my $self = shift;
      my $fh = $self->{fh};
      while (<$fh>) {
         $self->{lines_read} += 1;

         s/^\s+(?=\S)//;
         s/\s+$//;
         s|\s*//.*$||;
         chomp;

         return $self->{command} = $_ if $_;
      }

   }

   sub command_type {
      my $self = shift;
      $_ = $self->{command};

      return 'C_ARITHMETIC' if /^(add|sub|neg|eq|gt|lt|and|or|not)$/;
      return 'C_PUSH' if /^push/;
      return 'C_POP' if /^pop/;
      return 'C_LABEL';
      return 'C_GOTO';
      return 'C_IF';
      return 'C_FUNCTION';
      return 'C_RETURN';
      return 'C_CALL';
   }

   sub arg1 {
      my $self = shift;

      my $command_type = $self->command_type;
      if ($command_type eq 'C_ARITHMETIC') {
         return $self->{command};
      }
      elsif ($command_type eq 'C_RETURN') {
         warn "Warning: Parser->args1 should not be called on $command_type";
         return;
      }

      my ($arg1) = $self->{command} =~ /^\w+\s+(\w+)/;
      return $arg1;
   }

   sub arg2 {
      my $self = shift;

      my $command_type = $self->command_type;
      if ($command_type !~ 'C_(PUSH|POP|FUNCTION|CALL)') {
         warn "Warning: Parser->args2 should not be called on $command_type";
         return;
      }

      my ($arg2) = $self->{command} =~ /(\w+)$/;
      return $arg2;
   }


package Writer;
   sub new { return bless {}, shift; }

   sub init {
      my ($self, $file) = @_;

      $file =~ s/\.\w+$/.asm/;
      $self->set_file($file)
   }

   sub set_file {
      my ($self, $file) = @_;

      open(my $fh, '>', $file) or die "Unable to open $file";
      $self->{fh} = $fh;
   }

   sub write_arithmetic {
      my ($self, $command) = @_;
      my $fh = $self->{fh};

      print $fh unindent('
            @SP
            M=M-1');

      if ($command eq 'add') {
         print $fh unindent('
            @SP
            A=M
            D=M
            @SP
            AM=M-1
            M=M+D');
      }
      elsif ($command eq 'sub') {
         print $fh unindent('
            @SP
            A=M
            D=M
            @SP
            AM=M-1
            M=M-D');
      }
      elsif ($command eq 'neg') {
         print $fh unindent('
            @SP
            A=M
            M=-M');
      }
      elsif ($command eq 'eq') {
         print $fh unindent('
            @SP
            A=M
            D=M
            @SP
            AM=M-1
            D=M-D
            @TRUE_' . $self->{label_count} . '
            D;JEQ
            @SP
            A=M
            M=0
            @END_' . $self->{label_count} . '
            0;JMP
            (TRUE_' . $self->{label_count} . ')
            @SP
            A=M
            M=-1
            (END_' . $self->{label_count} . ')');

         $self->{label_count} += 1;
      }
      elsif ($command eq 'gt') {
         print $fh unindent('
            @SP
            A=M
            D=M
            @SP
            AM=M-1
            D=M-D
            @TRUE_' . $self->{label_count} . '
            D;JGT
            @SP
            A=M
            M=0
            @END_' . $self->{label_count} . '
            0;JMP
            (TRUE_' . $self->{label_count} . ')
            @SP
            A=M
            M=-1
            (END_' . $self->{label_count} . ')');

         $self->{label_count} += 1;
      }
      elsif ($command eq 'lt') {
         print $fh unindent('
            @SP
            A=M
            D=M
            @SP
            AM=M-1
            D=M-D
            @TRUE_' . $self->{label_count} . '
            D;JLT
            @SP
            A=M
            M=0
            @END_' . $self->{label_count} . '
            0;JMP
            (TRUE_' . $self->{label_count} . ')
            @SP
            A=M
            M=-1
            (END_' . $self->{label_count} . ')');

         $self->{label_count} += 1;
      }
      elsif ($command eq 'and') {
         print $fh unindent('
            @SP
            A=M
            D=M
            @SP
            AM=M-1
            M=M&D');
      }
      elsif ($command eq 'or') {
         print $fh unindent('
            @SP
            A=M
            D=M
            @SP
            AM=M-1
            M=M|D');
      }
      elsif ($command eq 'not') {
         print $fh unindent('
            @SP
            A=M
            M=!M');
      }
      else {
         die "Fatal: Unknown command $command"
      }

      print $fh unindent('
         @SP
         M=M+1');
   }

   sub write_push_pop {
      my ($self, $command_type, $segment, $index) = @_;
      my $fh = $self->{fh};

      if (   $segment eq 'argument') {
      }
      elsif ($segment eq 'local') {
      }
      elsif ($segment eq 'static') {
      }
      elsif ($segment eq 'constant') {
         print $fh unindent('
            @' . $index . '
            D=A
            @SP
            A=M
            M=D');
      }
      elsif ($segment eq 'this') {
      }
      elsif ($segment eq 'that') {
      }
      elsif ($segment eq 'pointer') {
      }
      elsif ($segment eq 'temp') {
      }
      else {
         die "Fatal: Unknown segment $segment";
      }

      if ($command_type eq 'C_PUSH') {
         print $fh unindent('
            @SP
            M=M+1');
      }
      elsif ($command_type eq 'C_POP') {
         print $fh unindent('
            @SP
            M=M-1');
      }
   }

   sub close_file {
      my $self = shift;
      close($self->{fh});
      delete $self->{fh};
   }

   sub unindent {
      my $str = shift;
      my ($whitespace) = substr($str, 1) =~ /^(\s+)/;
      $str =~ s/$whitespace//mg;
      return $str;
   }


