#!/bin/perl
use strict;
use warnings;
use PPI;
use File::Find::Rule;
use List::MoreUtils qw(uniq);
# use Data::Dumper;
use File::Path qw(make_path);

my $PPICacheDir;
BEGIN {
    $PPICacheDir = '.cache/PPI';
    unless(-d $PPICacheDir) {
        make_path($PPICacheDir) or die qq[Directory $PPICacheDir coldn't be created: $!];
    }
};

use PPI::Cache path => $PPICacheDir;

my @directories = @ARGV;


my %seen;  # Hash, um Duplikate zu verfolgen
my @unique_package_names;

# Alle Perl-Moduldateien im Verzeichnisbaum finden
foreach my $directory (@directories) {

    my @files = File::Find::Rule->file()->name('*.pm')->in($directory);

    foreach my $file (@files) {

        my $document = PPI::Document->new($file, readonly => 1);
        next unless $document;
        # Alle package-Anweisungen in der Datei finden
        my $package_statements = $document->find('PPI::Statement::Package');

        # Nur Dateien mit mindestens einer package-Anweisung verarbeiten
        next unless $package_statements;

        foreach my $package_statement (@$package_statements) {
            my $package_name = $package_statement->namespace;

            next if $seen{$package_name};
            $seen{$package_name} = 1;

            push @unique_package_names, $package_name;

            # print "Paketname: $package_name\n";
        }
    }
}
# Paketnamen mit | getrennt ausgeben
my $package_string = join '$|', @unique_package_names;
print "$package_string\$";

# Example:
# FHEM_MODULES=$(./scripts/get-Packages.pl src/fhem/trunk/fhem)
