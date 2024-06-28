#!/usr/bin/env perl 

use warnings;
use strict;
use Data::Dumper;
use Getopt::Long;
use File::Basename qw/basename/;
use File::Temp qw/tempdir/;

use FindBin;
use lib "$FindBin::RealBin/../lib/perl5";
use lib "$FindBin::RealBin/../lib/perl5/x86_64-linux-thread-multi";

use Dists2;

use version 0.77;

local $0 = basename $0;
sub logmsg{local $0=basename $0; print STDERR "$0: @_\n";}
exit(main());

sub main{
  my $settings={};
  GetOptions($settings,qw(help tempdir=s informat=s outformat=s on-disk symmetric)) or die $!;
  usage() if($$settings{help} || -t STDIN);

  $$settings{informat}||="tsv";
  $$settings{outformat}||="tsv";
  $$settings{"on-disk"}||=0;
  $$settings{tempdir} ||= tempdir("dists2.XXXXXX", TMPDIR => 1, CLEANUP => 1);

  my $distances = readDistances($$settings{informat}, $settings);
  makeSymmetric($distances, $settings) if($$settings{symmetric});
  printDistances($distances, $$settings{outformat}, $settings);

  return 0;
}

sub readDistances{
  my ($format, $settings) = @_;
  my %dist;

  if($$settings{'on-disk'}){
    my $dbpath = $$settings{tempdir}. "/distances.db";
    tie %dist, 'Tie::Hash::DBD', 'dbi:SQLite:dbname='.$dbpath,
      {
        str   => "Storable",
      };
  }

  if($format eq 'tsv'){
    while(<>){
      chomp;
      my ($sample1, $sample2, $dist) = split /\t/;
      $dist{$sample1}{$sample2} = $dist;
    }
    die Dumper \%dist;
  } elsif($format eq 'matrix'){
    my $sample2 = <>;
    chomp($sample2);
    my @sample2 = split /\t/, $sample2;
    shift(@sample2); # remove the first column
    while(<>){
      chomp;
      my @F = split /\t/;
      my $sample1 = shift(@F);
      for my $j(0..$#F){
        $dist{$sample1}{$sample2[$j]} = $F[$j];
      }
    }
  } elsif($format eq 'phylip'){
    my $numSamples = <>;
    $numSamples =~ s/^\s+|\s+$//g;
    $numSamples =~ /\D/ 
      and die "ERROR: I was expecting a number of samples in the first line of the phylip file but got $numSamples";
    my $sampleIdx=0;
    my @sampleName;
    my @distMatrix;
    # Load the distances into a 2d matrix but we don't have
    # the sample names yet.
    while(<>){
      chomp;
      my ($sample1, @dist) = split /\s+/;
      push(@sampleName, $sample1);
      $distMatrix[$sampleIdx] = \@dist;
      $sampleIdx++;
    }

    # Turn the distance matrix into a hash
    for my $i(0..$#sampleName){
      for my $j(0..$#sampleName){
        $dist{$sampleName[$i]}{$sampleName[$j]} = $distMatrix[$i][$j];
      }
    }

  } else {
    die "ERROR: I do not recognize the format $format";
  }

  return \%dist;
}

sub makeSymmetric{
  my ($distances, $settings) = @_;

  my @sample = sort keys(%$distances);
  # there is always one extra sample that does not appear in the set of first samples
  # so we need to add it to the list of samples
  push(@sample, keys(%{$$distances{$sample[0]}}));
  # Now make the list unique again
  @sample = sort do{my %seen; grep{!$seen{$_}++} @sample};
  my $numSamples = scalar(@sample);

  for(my $i=0; $i<$numSamples; $i++){
    my $sample1 = $sample[$i];
    for(my $j=0; $j<$numSamples; $j++){
      my $sample2 = $sample[$j];
      
      # Set a default of zero for distances that do not exist
      $$distances{$sample1}{$sample2} //= 0;
      $$distances{$sample2}{$sample1} //= 0;
      
      my $dist1 = $$distances{$sample1}{$sample2};
      my $dist2 = $$distances{$sample2}{$sample1};
      if(!$dist1 && $dist2){
        $$distances{$sample1}{$sample2} = $dist2;
        logmsg "Setting $sample1 $sample2 to $dist2";
      } elsif($dist1 && !$dist2){
        $$distances{$sample2}{$sample1} = $dist1;
        logmsg "Setting $sample2 $sample1 to $dist1";
      } elsif($dist1 != $dist2){
        logmsg "WARNING: $sample1 $sample2 has a distance of $dist1 while $sample2 $sample1 has a distance of $dist2. I am setting the distance to the average of the two.";
        my $avg = ($dist1 + $dist2)/2;
        $$distances{$sample1}{$sample2} = $avg;
        $$distances{$sample2}{$sample1} = $avg;
      }
    }
  }
}

sub printDistances{
  my ($distances, $format, $settings) = @_;

  my @sample = sort keys(%$distances);
  # there is always one extra sample that does not appear in the set of first samples
  # so we need to add it to the list of samples
  push(@sample, keys(%{$$distances{$sample[0]}}));
  # Now make the list unique again
  @sample = sort do{my %seen; grep{!$seen{$_}++} @sample};
  my $numSamples = scalar(@sample);

  if($format eq 'phylip'){
    print "    $numSamples\n";
    for my $i(0..$#sample){
      my $sample1 = $sample[$i];
      print $sample1;

      my $minJ = ($$settings{symmetric}) ? 0 : $i+1;
      for(my $j=$minJ; $j<$numSamples; $j++){
        my $sample2 = $sample[$j];
        print "  " . $$distances{$sample1}{$sample2};
      }
      print "\n";
    }
  } elsif($format eq 'tsv'){
    for my $sample1(@sample){
      for my $sample2(@sample){
        print join("\t", $sample1, $sample2, $$distances{$sample1}{$sample2})."\n";
      }
    }
  } elsif($format eq 'matrix'){
    print join("\t", "samples", @sample)."\n";
    for my $sample1(@sample){
      print $sample1;
      for my $sample2(@sample){
        print "\t" . $$distances{$sample1}{$sample2};
      }
      print "\n";
    }
  } else {
    die "ERROR: I do not recognize the format $format";
  }

  return $numSamples;
}

sub usage{
  print "$0: Converts between distance types
  Usage: $0 [options] < infile > outfile
  --informat  FORMAT  The input format.  Default: tsv
  --outformat FORMAT  The output format. Default: tsv
  --symmetric         Make the matrix symmetric. Default: off
  --on-disk           Use an on-disk database to store the 
                      distances temporarily.
  --help              This useful help menu

  FORMAT can be: tsv, matrix, or phylip
    where tsv is a three column format of sample1 sample2 distance
    and matrix is a matrix of distances, tab separated, with a header of samples and a first column naming the sample. The first row of the first column needs to have a value but is not read.
    and phylip is a standard format of distances
  \n";
  exit 0;
}
