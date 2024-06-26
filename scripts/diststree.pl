#!/usr/bin/env perl 

use warnings;
use strict;
use Data::Dumper;
use Getopt::Long;
use File::Basename qw/basename/;
use File::Temp qw/tempdir/;
use File::Which qw/which/;

use version 0.77;
our $VERSION = '0.1.1';

local $0 = basename $0;
sub logmsg{local $0=basename $0; print STDERR "$0: @_\n";}
exit(main());

sub main{
  my $settings={};
  GetOptions($settings,qw(help tempdir=s)) or die $!;
  usage() if($$settings{help} || -t STDIN);
  $$settings{tempdir} //= tempdir("diststree.XXXXXX", TMPDIR => 1, CLEANUP => 1);

  for my $exe(qw(quicktree gotree)){
    which($exe) or die "ERROR: could not find $exe in your PATH";
  }

  makeTree($settings);

  return 0;
}

sub makeTree{
  my($settings) = @_;

  # Write the input tree to file for quicktree
  my $intree = $$settings{tempdir}."/stdin.dnd";
  open(my $fh, ">", $intree) or die "ERROR: could not write to $intree: $!";
  while(<>){
    print $fh $_;
  }
  close $fh;

  my $outtree = "$$settings{tempdir}/stdout.dnd";

  system("quicktree -in m -out t $intree > $outtree");
  die "ERROR with quicktree: $!" if $?;

  system("gotree reformat newick -f newick < $outtree");
  die "ERROR with gotree: $!" if $?;
}

sub usage{
  print "$0: makes trees from phylip distances
  Usage: $0 [options] < infile > outfile.newick
  --help              This useful help menu
  \n";
  exit 0;
}
