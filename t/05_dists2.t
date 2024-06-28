#!/usr/bin/env perl

use strict;
use warnings;
use lib './lib';
use File::Basename qw/dirname/;
use FindBin qw/$RealBin/;
use Data::Dumper;

use Test::More tests => 4;

$ENV{PATH} = "$RealBin/../scripts:".$ENV{PATH};

diag `dists2.pl --help 2>&1`;
my $exit_code = $? << 8;
is($exit_code, 0, "exit code");

my $testTsv = "$RealBin/data/tallskinny.tsv";
mkdir "$RealBin/data";
END{
    for my $file(glob("$RealBin/data/*")){
        unlink $file;
    }
}

subtest 'Make sample data' => sub{
    # Set the random seed to make this deterministic
    srand(42);

    open(my $fh, ">", $testTsv) or die "ERROR: could not write to $testTsv: $!";
    for(my $i=0;$i<4; $i++){
        for(my $j=0;$j<4;$j++){
            my $dist = 0;
            if($i != $j){
                $dist = int(rand(5));
            }
            print $fh join("\t", $i, $j, $dist)."\n";
        }
    }
    close $fh;

    isnt(-e $testTsv, 0, "Created test file");
};

subtest 'tsv => phylip' => sub{
    system("dists2.pl --informat tsv --outformat phylip --symmetric < $testTsv > $testTsv.phylip");
    is($?, 0, "dists2.pl ran successfully on tsv => phylip");

    # Back again
    system("dists2.pl --informat phylip --outformat tsv --symmetric < $testTsv.phylip > $testTsv.phylip.tsv");
    is($?, 0, "dists2.pl ran successfully on phylip => tsv");

    # One more round to check file contents
    system("dists2.pl --informat tsv --outformat phylip --symmetric < $testTsv.phylip.tsv > $testTsv.phylip.tsv.phylip");
    system("dists2.pl --informat phylip --outformat tsv --symmetric < $testTsv.phylip.tsv.phylip > $testTsv.phylip.tsv.phylip.tsv");
    # check to see if the last two tsv files are the same.
    my ($content1,$content2);
    {
        local $/ = undef;
        open(my $fh1, "<", "$testTsv.phylip.tsv") or die "ERROR: could not read $testTsv.phylip.tsv: $!";
        $content1 = <$fh1>;
        close $fh1;
        open(my $fh2, "<", "$testTsv.phylip.tsv.phylip.tsv") or die "ERROR: could not read $testTsv.phylip.tsv.phylip.tsv: $!";
        $content2 = <$fh2>;
        close $fh2;
    }
    is($content1, $content2, "convergence converting back and forth: phylip => tsv => phylip => tsv");
};

subtest 'matrix => phylip' => sub{
    # Test the special case of matrix => phylip
    # First make the matrix file
    my $testMatrix = "$RealBin/data/matrix.tsv";
    system("dists2.pl --informat tsv --outformat matrix --symmetric < $testTsv > $testMatrix");
    is($?, 0, "dists2.pl ran successfully on tsv => matrix");

    system("dists2.pl --informat matrix --outformat phylip --symmetric < $testMatrix > $testMatrix.phylip");
    is($?, 0, "dists2.pl ran successfully on matrix => phylip");

    system("dists2.pl --informat phylip --outformat matrix --symmetric < $testMatrix.phylip > $testMatrix.phylip.matrix");
    is($?, 0, "dists2.pl ran successfully on phylip => matrix");

    # check to see if the last two matrix files are the same.
    my ($content3,$content4);
    {
        local $/ = undef;
        open(my $fh1, "<", "$testTsv.phylip.tsv") or die "ERROR: could not read $testTsv.phylip.tsv: $!";
        $content3 = <$fh1>;
        close $fh1;
        open(my $fh2, "<", "$testTsv.phylip.tsv.phylip.tsv") or die "ERROR: could not read $testTsv.phylip.tsv.phylip.tsv: $!";
        $content4 = <$fh2>;
        close $fh2;
    }
    is($content3, $content4, "convergence converting back and forth: matrix => phylip => matrix => phylip");
}