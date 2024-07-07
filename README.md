# dists2trees

Converts between distance formats. Also: making trees from those distances.

## Installation

```bash
git clone git@github.com:lskatz/dists2trees.git
export PATH=$PATH:$(realpath dists2trees/scripts)
```

This package depends on

* perl
* gotree
* quicktree

## Usage

### Make a tree from distances

```text
  Usage: diststree.pl [options] < infile > outfile.newick
  --help              This useful help menu
```

### Convert between distances formats

```text

  Usage: dists2.pl [options] < infile > outfile
  --informat  FORMAT  The input format.  Default: tsv
  --outformat FORMAT  The output format. Default: stsv
  --symmetric         Make the matrix symmetric. Default: off
  --help              This useful help menu

  FORMAT can be: tsv, stsv, matrix, or phylip
    where tsv is a three column format of sample1 sample2 distance
    and stsv is a tsv file where the samples are sorted (`sort -k1,2n`)
    and matrix is a matrix of distances, tab separated, with a header of samples and a first column naming the sample. The first row of the first column needs to have a value but is not read.
    and phylip is a standard format of distances
```

Some optimizations have been made for

* stsv (sorted tsv) to matrix
* matrix to phylip

## Examples

### Convert between tsv and phylip format

Make example data:

```bash
# use bash -c '' trick to set a stable random seed for this example
bash -c '
  RANDOM=42; 
  for i in {1..4}; do 
    for j in `seq $(($i+1)) 4`; do 
    if [ $i == $j ]; then 
      rand=0; 
    else 
      rand=$RANDOM; 
    fi; 
    echo -e "$i\t$j\t$rand"; 
  done; 
done' > distances.tsv

cat distances.tsv
1       2       17766
1       3       11151
1       4       23481
2       3       32503
2       4       7018
3       4       25817
```

Convert to phylip from tsv format.
In this example since distances back and forth between samples are not defined,
there are stderr messages showing what was corrected.
If distances are defined and not equal, they will be averaged.
This correction happens when you specify `--symmetric`.

```bash
perl scripts/dists2.pl --outformat phylip --symmetric < distances.tsv | column -t
dists2.pl: Setting 2 1 to 17766
dists2.pl: Setting 3 1 to 11151
dists2.pl: Setting 4 1 to 23481
dists2.pl: Setting 3 2 to 32503
dists2.pl: Setting 4 2 to 7018
dists2.pl: Setting 4 3 to 25817
4
1  0      17766  11151  23481
2  17766  0      32503  7018
3  11151  32503  0      25817
4  23481  7018   25817  0
```

### Make a tree

```bash
perl scripts/dists2.pl --outformat phylip --symmetric < distances.tsv | \
  perl scripts/diststree.pl 

(2:3751.75,(3:9843.75,1:1307.25):15807.25,4:3266.25);
```

### Make bootstraps

Bootstraps are a test of how different kinds of perturbations or randomness will affect your tree.
So for this example, I will make some randomness in the input.

```bash
mkdir bootstraps
for i in {1..100}; do
  cat distances.tsv | \
    perl -lane '
      # give distances ±50
      $rand = int(rand(100)); 
      $rand = $rand - 50;  
      $F[2] += $rand; 
      # Print the new value to stdout
      print join("\t", @F);
    ' > bootstraps/dist.$i.tsv; 
  # Transform these distances to phylip and then into a tree.
  # The trees are being printed to stdout, but
  # stdout will be printed to a file at the end of the loop.
  perl scripts/dists2.pl --symmetric --outformat phylip < bootstraps/dist.$i.tsv | \
    perl scripts/diststree.pl 
done > bootstraps.dnd
# => bootstraps.dnd should have 100 trees in it now
# Get rid of the folder with distances in it, now that we have BS trees
rm -rf bootstraps

head -n 3 bootstraps.dnd 
(2:3739.5,(3:9834,1:1271):15834,4:3283.5);
(2:3754.5,(3:9849,1:1338):15753.5,4:3279.5);
(2:3702.75,(3:9850.75,1:1329.25):15806.75,4:3300.25);
```

Run `gotree` to add supports

```bash
perl scripts/dists2.pl --outformat phylip --symmetric < distances.tsv | \
  perl scripts/diststree.pl | \
  gotree compute support classical --bootstrap bootstraps.dnd > withbs.dnd
Classical Support
Start       : 26 Jun 24 14:55 EDT
Input tree  : stdin
Boot trees  : bootstraps.dnd
Output tree : stdout
CPUs        : 1
dists2.pl: Setting 2 1 to 17766
dists2.pl: Setting 3 1 to 11151
dists2.pl: Setting 4 1 to 23481
dists2.pl: Setting 3 2 to 32503
dists2.pl: Setting 4 2 to 7018
dists2.pl: Setting 4 3 to 25817
End         : 26 Jun 24 14:55 EDT
```

Draw the tree for fun

```bash
cat withbs.dnd
(2:3751.75,(3:9843.75,1:1307.25)1:15807.25,4:3266.25);

cat withbs.dnd | gotree draw text
+---------------------------- 2                                                                                                                                                                                   
|                                                                                                                                                                                                                 
|                                                                                                                          +--------------------------------------------------------------------------- 3         
|--------------------------------------------------------------------------------------------------------------------------|                                                                                      
|                                                                                                                          +--------- 1                                                                           
|                                                                                                                                                                                                                 
+------------------------ 4             
```
