#!/usr/bin/perl
# assembler.pl
# Author:  Nick Platt <platt.nicholas@gmail.com>
# License: MIT <http://opensource.org/licenses/MIT>

use strict;
use warnings;
no warnings 'uninitialized';

die "Usage: assembler.pl <file>" unless $ARGV[0];

package main;
   my $assembler = Assembler->new;
   $assembler->init;
   $assembler->load_file($ARGV[0]);
   $assembler->parse_symbols;
   $assembler->translate;


package Assembler;
   sub new { return bless {}, shift; }

   sub init {
      my $self = shift;

      $self->{parser} = Parser->new;
      $self->{symbol_table} = SymbolTable->new;

      my %predefined_symbols = (
         SP     => 0,
         LCL    => 1,
         ARG    => 2,
         THIS   => 3,
         THAT   => 4,
         R0     => 0,
         R1     => 1,
         R2     => 2,
         R3     => 3,
         R4     => 4,
         R5     => 5,
         R6     => 6,
         R7     => 7,
         R8     => 8,
         R9     => 9,
         R10    => 10,
         R11    => 11,
         R12    => 12,
         R13    => 13,
         R14    => 14,
         R15    => 15,
         SCREEN => 16384,
         KBD    => 14576,
      );

      foreach my $symbol (keys %predefined_symbols) {
         $self->{symbol_table}->add($symbol, $predefined_symbols{$symbol});
      }
   }

   sub load_file {
      my ($self, $file) = @_;

      open(my $fh, '<', $file) or die "Unable to open $file";
      $self->{parser}->load_file($fh);
   }


   sub parse_symbols {
      my $self = shift;

      my $rom_address = 0;
      while ($self->{parser}->can_advance) {
         $self->{parser}->advance;

         if ($self->{parser}->command_type eq 'LABEL') {
            $self->{symbol_table}->add(
                  $self->{parser}->symbol,
                  $rom_address
               );
         }
         else {
            $rom_address += 1;
         }
      }

      $self->{parser}->rewind;
   }

   sub translate {
      my $self = shift;

      my $symbol_offset = 16;
      while ($self->{parser}->can_advance) {
         $self->{parser}->advance;
         #printf "%-30s %-30s",
         #   $self->{parser}->{command},
         #   $self->{parser}->symbol unless $self->{parser}->command_type eq 'LABEL';

         if ($self->{parser}->command_type eq 'ADDRESS') {
            if ($self->{parser}->symbol =~ /^\d+$/) {
               printf "%016b\n", $self->{parser}->symbol;
            }
            else {
               if (!$self->{symbol_table}->contains(
                        $self->{parser}->symbol
                     )) {
                     $self->{symbol_table}->add(
                        $self->{parser}->symbol,
                        $symbol_offset
                     );
                     $symbol_offset += 1;
               }

               printf "%016b\n", $self->{symbol_table}->get_address(
                     $self->{parser}->symbol
                  );
            }

         }
         elsif ($self->{parser}->command_type eq 'LABEL') {
         }
         elsif ($self->{parser}->command_type eq 'COMPUTATION') {
            printf "111%s%s%s\n",
               Code::comp($self->{parser}->comp),
               Code::dest($self->{parser}->dest),
               Code::jump($self->{parser}->jump);
         }
         else {
            die "Failed to translate command: $self->{parser}->{command}";
         }
      }
   }


package Parser;
   sub new { return bless {}, shift; }

  sub load_file {
      my ($self, $fh) = @_;
      $self->{fh} = $fh;
   }

   sub rewind {
      my $self = shift;
      seek $self->{fh}, 0, 0;
      $self->{lines_read} = 0;
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

      return 'ADDRESS' if /@/;
      return 'LABEL' if /\(/;
      return 'COMPUTATION' if /=|;|^[^()=;]+$/;
   }

   sub symbol {
      my $self = shift;
      my ($symbol) = $self->{command} =~ /^(?:\@|\()([A-Za-z0-9_.\$\:]+)\)?$/;
      return $symbol;
   }

   sub dest {
      my $self = shift;
      my ($dest) = $self->{command} =~ /^(.+)=/;
      return $dest;
   }

   sub comp {
      my $self = shift;
      my ($comp) = $self->{command} =~ /((?<==)[^;]+|[^=]+(?=;)|^[^()=;]+$)/;
      return $comp;
   }

   sub jump {
      my $self = shift;
      my ($jump) = $self->{command} =~ /(?<=;)(.+)$/;
      return $jump;
   }


package SymbolTable;
   sub new { return bless {}, shift; }

   sub add {
      my ($self, $symbol, $address) = @_;
      return $self->{$symbol} = $address;
   }

   sub contains {
      my ($self, $symbol) = @_;
      return 1 if defined $self->{$symbol};
   }

   sub get_address {
      my ($self, $symbol) = @_;
      return $self->{$symbol} if defined $self->{$symbol};
      die "Undefined symbol: >$symbol<";
   }


package Code;
   sub dest {
      $_ = shift;

      return "000" if /^$/;
      return "001" if /^M$/;
      return "010" if /^D$/;
      return "011" if /^MD$/;
      return "100" if /^A$/;
      return "101" if /^AM$/;
      return "110" if /^AD$/;
      return "111" if /^AMD$/;
   }

   sub comp {
      $_ = shift;

      return "0101010" if /^0$/;
      return "0111111" if /^1$/;
      return "0111010" if /^-1$/;
      return "0001100" if /^D$/;
      return "0110000" if /^A$/;
      return "1110000" if /^M$/;
      return "0001101" if /^!D$/;
      return "0110001" if /^!A$/;
      return "1110001" if /^!M$/;
      return "0001111" if /^-D$/;
      return "0110011" if /^-A$/;
      return "1110011" if /^M$/;
      return "0011111" if /^D\+1$/;
      return "0110111" if /^A\+1$/;
      return "1110111" if /^M\+1$/;
      return "0001110" if /^D-1$/;
      return "0110010" if /^A-1$/;
      return "1110010" if /^M-1$/;
      return "0000010" if /^D\+A|A\+D$/;
      return "1000010" if /^D\+M|M\+D$/;
      return "0010011" if /^D-A$/;
      return "1010011" if /^D-M$/;
      return "0000111" if /^A-D$/;
      return "1000111" if /^M-D$/;
      return "0000000" if /^D&A|A&D$/;
      return "1000000" if /^D&M|M&D$/;
      return "0010101" if /^D\|A|A\|D$/;
      return "1010101" if /^D\|M|M\|D/;
   }

   sub jump {
      $_ = shift;

      return "000" if /^$/;
      return "001" if /^JGT$/;
      return "010" if /^JEQ$/;
      return "011" if /^JGE$/;
      return "100" if /^JLT$/;
      return "101" if /^JNE$/;
      return "110" if /^JLE$/;
      return "111" if /^JMP$/;
   }
