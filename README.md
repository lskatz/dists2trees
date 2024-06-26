# dists2trees

Converts between distance formats

TODO: transform distances to trees

## Usage

```text
  Usage: dists2.pl [options] < infile > outfile
  --informat  FORMAT  The input format.  Default: tsv
  --outformat FORMAT  The output format. Default: tsv
  --symmetric         Make the matrix symmetric. Default: off
  --help              This useful help menu

  FORMAT can be: tsv, matrix, or phylip
    where tsv is a three column format of sample1 sample2 distance
    and matrix is a matrix of distances, tab separated, with a header of samples and a first column naming the sample. The first row of the first column needs to have a value but is not read.
    and phylip is a standard format of distances
```

## Examples

Convert between tsv and phylip format

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
In this example since distances back and forth between samples are not equal,
there are stderr messages showing what was corrected.
This correction happens when you specify `--symmetric`.

```bash
perl scripts/dists2.pl --outformat phylip --symmetric | column -t
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
