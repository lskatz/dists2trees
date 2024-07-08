use strict;
use warnings;
use FindBin qw/$RealBin/;
use File::Which qw/which/;
use Test::More tests => 3;

$ENV{PATH} = "$RealBin/../scripts:".$ENV{PATH};

my $testTsv = "$RealBin/data/tallskinny.tsv";
mkdir "$RealBin/data";
END{
    for my $file(glob("$RealBin/data/*")){
        unlink $file;
    }
}

subtest 'Dependencies' => sub{
  system("diststree.pl --check");
  is($?, 0, "Dependencies are met");
};

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
  isnt(-e $testTsv, 0, "Created test tsv file");

  system("dists2.pl --informat tsv --outformat phylip --symmetric < $testTsv > $testTsv.phylip");
  isnt(-e "$testTsv.phylip", 0, "Created test phylip file");
};

subtest 'trees' => sub{

  subtest 'quicktree' => sub{
    srand(42);
    system("diststree.pl --algorithm quicktree < $testTsv.phylip > $testTsv.phylip.newick");
    is($?, 0, "diststree.pl ran successfully");
    isnt(-e "$testTsv.phylip.newick", 0, "Created test newick file");
  
    my $exp = "(1:1,(2:0.25,0:1.25):0.5,3:2);";
    open(my $fh, "<", "$testTsv.phylip.newick") or die "ERROR: could not read $testTsv.phylip.newick: $!";
    my $obs = <$fh>;
    chomp($obs);
    close $fh;
    is($obs, $exp, "Expected newick tree");
  };

  subtest 'rapidnj' => sub{
    srand(42);
    system("diststree.pl --algorithm rapidnj < $testTsv.phylip > $testTsv.phylip.newick");
    is($?, 0, "diststree.pl ran successfully");
    isnt(-e "$testTsv.phylip.newick", 0, "Created test newick file");

    my $exp = "(('2':0.25,'0':1.25):0.5,'1':1,'3':2);";
    open(my $fh, "<", "$testTsv.phylip.newick") or die "ERROR: could not read $testTsv.phylip.newick: $!";
    my $obs = <$fh>;
    chomp($obs);
    close $fh;
    is($obs, $exp, "Expected newick tree");
  };
};