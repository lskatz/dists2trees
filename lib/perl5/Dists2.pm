package Dists2;

use strict;
use warnings;
use File::Temp qw(tempdir);
use Exporter qw(import);
use version; 
our $VERSION = version->declare("0.2.0");

our @EXPORT_OK = (); # Add your exported functions here

sub new {
    my ($class, $settings) = @_;
    
    # Create temporary directory
    my $tempdir = tempdir("DISTS2.XXXX", TMPDIR => 1, CLEANUP => 1);
    my $db = "$tempdir/dists.db.tsv";
    open(my $fh, ">", $db) or die "ERROR: could not make temporary file $db: $!";
    
    # Make the object and then bless it.
    my $self = {
        settings => $settings,
        tempdir  => $tempdir,
        db => $db,
        fh => $fh,
    };
    bless($self, $class);
    return $self;
}

sub TIEHASH{
    my ($class, $settings) = @_;
    return $class->new($settings);
}

sub FETCH{
    my ($self, $key) = @_;
    return $self->{$key};
}

sub STORE{
    my ($self, $key, $value) = @_;
    print { $self->{fh} } "$key\t$value\n";
}

sub DELETE{
    my ($self, $key) = @_;
    ...;
    delete $self->{$key};
}

sub EXISTS{
    my ($self, $key) = @_;
    ...;
    return exists $self->{$key};
}

1;
