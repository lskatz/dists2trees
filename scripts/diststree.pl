#!/usr/bin/env perl 

use warnings;
use strict;
use Data::Dumper;
use Getopt::Long;
use File::Basename qw/basename/;
use File::Temp qw/tempdir/;
use File::Which qw/which/;

local $0 = basename $0;
sub logmsg{local $0=basename $0; print STDERR "$0: @_\n";}
exit(main());

sub main{
  my $settings={};
  GetOptions($settings,qw(help check tempdir=s numcpus=i algorithm=s)) or die $!;
  if($$settings{check}){
    for my $exe(qw(quicktree rapidnj gotree)){
      my $path = which($exe) or die "ERROR: could not find $exe in your PATH";
      logmsg "Found $exe at $path";
    }
    return 0;
  }

  usage() if($$settings{help} || -t STDIN);
  $$settings{tempdir} //= tempdir("diststree.XXXXXX", TMPDIR => 1, CLEANUP => 1);
  $$settings{algorithm} //= "quicktree";
  $$settings{numcpus} ||= 1;

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

  if($$settings{algorithm} eq 'quicktree'){
    system("quicktree -in m -out t $intree > $outtree");
    die "ERROR with quicktree: $!" if $?;
  } 
  elsif($$settings{algorithm} eq 'rapidnj'){
    system("rapidnj --input-format pd --output-format t --cores $$settings{numcpus} $intree > $outtree");
    die "ERROR with rapidnj: $!" if $?;
  } else {
    die "ERROR: unknown algorithm $$settings{algorithm}";
  }

  system("gotree reformat newick -f newick < $outtree");
  die "ERROR with gotree: $!" if $?;
}

sub usage{
  print "$0: makes trees from phylip distances
  Usage: $0 [options] < infile > outfile.newick
  --algorithm         quicktree|rapidnj  Default: quicktree
  --check             Check for all dependencies and then exit
  --numcpus           default: 1
  --tempdir           default: a temporary directory that will be deleted.
                      If provided, then the tempdir will not be deleted.
  --help              This useful help menu
  \n";
  exit 0;
}
