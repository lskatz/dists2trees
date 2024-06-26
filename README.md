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

