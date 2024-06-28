#!/usr/bin/env perl 

use warnings;
use strict;
use Data::Dumper;
use Getopt::Long;
use File::Basename qw/basename/;
use File::Temp qw/tempdir/;

# Using gzip for large temporary files will save on disk I/O
use IO::Compress::Gzip qw/gzip $GzipError/;
use IO::Uncompress::Gunzip qw/gunzip $GunzipError/;

use version 0.77;
our $VERSION = '0.3.0';

local $0 = basename $0;
sub logmsg{local $0=basename $0; print STDERR "$0: @_\n";}
exit(main());

sub main{
  my $settings={};
  GetOptions($settings,qw(help informat=s outformat=s symmetric tempdir=s verbose)) or die $!;
  usage() if($$settings{help} || -t STDIN);

  $$settings{informat}||="tsv";
  $$settings{outformat}||="tsv";
  $$settings{tempdir} ||= tempdir("dists2.XXXXXX", TMPDIR => 1, CLEANUP => 1);
  mkdir($$settings{tempdir});

  # special conversion cases
  if($$settings{informat} eq 'matrix' && $$settings{outformat} eq 'phylip'){
    if($$settings{verbose}){
      logmsg "Detected a special case matrix => phylip and so I will use a special streaming operation instead of loading it all into memory";
    }
    matrixToPhylip($settings);
  }

  # General cases of conversion 
  else{
    my $distances = readDistances($$settings{informat}, $settings);
    makeSymmetric($distances, $settings) if($$settings{symmetric});
    printDistances($distances, $$settings{outformat}, $settings);
  }
  return 0;
}

sub matrixToPhylip{
  my ($settings) = @_;
  # This will take about two passes:
  # 1) make a temporary file that has the phylip contents while validating the input
  # 2) print the phylip contents to stdout along with taxa count in the header

  # Read the streaming input to get the number of samples
  # and to validate the column/row orders match.
  # Save to a temp file at the same time.
  my $unvalidatedPhylip = "$$settings{tempdir}/unvalidated.phylip.gz";
  my $z = new IO::Compress::Gzip $unvalidatedPhylip
    or die "ERROR: could not write to $unvalidatedPhylip: $GzipError";
  # Read stdin matrix
  my $header = <>;
  chomp($header);
  my @header = split /\t/, $header;
  my $topLeft = shift(@header); # Top left value doesn't strictly have a meaning here
  my $expectedSamples = scalar(@header);
  # We assume that the first column will have the samples sorted
  # so that later we can check against @header.
  my @sortedSample;
  while(<>){
    chomp;
    my ($sample1, @dist) = split /\t/;
    push(@sortedSample, $sample1);
    if(scalar(@dist) != scalar(@header)){
      my $numDists = scalar(@dist);
      die "ERROR: the number of distances for sample $sample1 (n=$numDists) does not match the number of samples in the header (n=$expectedSamples)";
    }
    # phylip format has spaces between fields
    print $z join("  ", $sample1, @dist)."\n";
  }
  close $z;

  # Now we need to validate that the samples are in the same order
  # as the header
  my $numSamples = scalar(@sortedSample);
  if($numSamples != $expectedSamples){
    die "ERROR: the number of samples in the header ($expectedSamples) does not match the number of samples in the data ($numSamples)";
  }
  for(my $i=0; $i<$numSamples; $i++){
    if($sortedSample[$i] ne $header[$i]){
      die "ERROR: the sample order in the header does not match the order of the samples in the data\n"
        . "The samples diverged at the $i-th sample: $sortedSample[$i] vs $header[$i]";
    }
  }

  # At this point it is validated and so plop the total 
  # number of samples on the top and send it on its way to stdout
  print "    $numSamples\n";
  my $unz = new IO::Uncompress::Gunzip $unvalidatedPhylip
    or die "ERROR: could not read $unvalidatedPhylip: $GunzipError";
  while(<$unz>){
    print;
  }
  close $unz;
}

sub readDistances{
  my ($format, $settings) = @_;
  my %dist;

  if($format eq 'tsv'){
    while(<>){
      chomp;
      my ($sample1, $sample2, $dist) = split /\t/;
      $dist{$sample1}{$sample2} = $dist;
    }
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
        logmsg "Setting $sample1 $sample2 to $dist2" if($$settings{verbose});
      } elsif($dist1 && !$dist2){
        $$distances{$sample2}{$sample1} = $dist1;
        logmsg "Setting $sample2 $sample1 to $dist1 if($$settings{verbose})";
      } elsif($dist1 != $dist2){
        logmsg "WARNING: $sample1 $sample2 has a distance of $dist1 while $sample2 $sample1 has a distance of $dist2. I am setting the distance to the average of the two." if($$settings{verbose});
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
  --verbose           Print more things to stderr
  --tempdir   DIR     A temporary directory to use. 
                      If not specified, then a temporary directory chosen by perl that will get deleted.
                      If specified, then the directory will not be deleted.
  --help              This useful help menu

  FORMAT can be: tsv, matrix, or phylip
    where tsv is a three column format of sample1 sample2 distance
    and matrix is a matrix of distances, tab separated, with a header of samples and a first column naming the sample. The first row of the first column needs to have a value but is not read.
    and phylip is a standard format of distances
  \n";
  exit 0;
}
