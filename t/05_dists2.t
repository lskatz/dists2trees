#!/usr/bin/env perl

use strict;
use warnings;
use lib './lib';
use File::Basename qw/dirname/;
use FindBin qw/$RealBin/;
use Data::Dumper;

use Test::More tests => 2;

$ENV{PATH} = "$RealBin/../scripts:".$ENV{PATH};

diag `dists2.pl --help 2>&1`;
my $exit_code = $? << 8;
is($exit_code, 0, "exit code");

subtest 'dists2.pl' => sub{
    # Set the random seed to make this deterministic
    srand(42);

    mkdir "$RealBin/data";
    my $testDist = "$RealBin/data/tallskinny.tsv";
    open(my $fh, ">", $testDist) or die "ERROR: could not write to $testDist: $!";
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

    system("dists2.pl --on-disk --informat tsv --outformat phylip --symmetric < $testDist > $testDist.phylip");
    is($?, 0, "dists2.pl ran successfully on tsv => phylip");

    # Back again
    system("dists2.pl --informat phylip --outformat tsv --symmetric < $testDist.phylip > $testDist.phylip.tsv");
    is($?, 0, "dists2.pl ran successfully on phylip => tsv");

    # One more round to check file contents
    system("dists2.pl --informat tsv --outformat phylip --symmetric < $testDist.phylip.tsv > $testDist.phylip.tsv.phylip");
    system("dists2.pl --informat phylip --outformat tsv --symmetric < $testDist.phylip.tsv.phylip > $testDist.phylip.tsv.phylip.tsv");
    # check to see if the last two tsv files are the same.
    my ($content1,$content2);
    {
        local $/ = undef;
        open(my $fh1, "<", "$testDist.phylip.tsv") or die "ERROR: could not read $testDist.phylip.tsv: $!";
        $content1 = <$fh1>;
        close $fh1;
        open(my $fh2, "<", "$testDist.phylip.tsv.phylip.tsv") or die "ERROR: could not read $testDist.phylip.tsv.phylip.tsv: $!";
        $content2 = <$fh2>;
        close $fh2;
    }
    is($content1, $content2, "convergence converting back and forth: phylip => tsv => phylip => tsv");
}