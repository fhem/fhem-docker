#!/bin/perl
use strict;
use warnings;

use File::Path qw(make_path);
use Getopt::Long qw(GetOptions);
use JSON::PP qw(encode_json);
use Module::CPANfile;

my @cpanfiles;
my $output_file;
my $label = 'requirements';

GetOptions(
    'cpanfile=s@'   => \@cpanfiles,
    'output-file=s' => \$output_file,
    'label=s'       => \$label,
) or die "Usage: $0 --cpanfile <path> [--cpanfile <path> ...] --output-file <path> [--label <name>]\n";

die "At least one --cpanfile is required\n" unless @cpanfiles;
die "--output-file is required\n" unless defined $output_file;

my %requirements;
for my $cpanfile_path (@cpanfiles) {
    my $cpanfile = Module::CPANfile->load($cpanfile_path);
    my $specs    = $cpanfile->prereq_specs;

    for my $phase ( keys %{$specs} ) {
        next unless ref $specs->{$phase} eq 'HASH';
        for my $relationship ( keys %{ $specs->{$phase} } ) {
            next unless ref $specs->{$phase}{$relationship} eq 'HASH';
            for my $module ( sort keys %{ $specs->{$phase}{$relationship} } ) {
                my $required = defined $specs->{$phase}{$relationship}{$module}
                  ? "$specs->{$phase}{$relationship}{$module}"
                  : q[];

                if ( !exists $requirements{$module} || $requirements{$module} eq q[] ) {
                    $requirements{$module} = $required;
                }
            }
        }
    }
}

my @entries = map {
    {
        module   => $_,
        required => $requirements{$_},
    }
} sort keys %requirements;

if ( $output_file =~ m{\A(.+)/[^/]+\z} ) {
    make_path($1) unless -d $1;
}

open( my $fh, '>', $output_file ) or die "Cannot open $output_file: $!";
print {$fh} encode_json(
    {
        label             => $label,
        requirements      => \@entries,
        requirement_count => scalar @entries,
        cpanfiles         => \@cpanfiles,
    }
) . "\n";
close($fh) or die "Cannot close $output_file: $!";
