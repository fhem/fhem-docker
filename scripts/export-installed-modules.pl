#!/bin/perl
use strict;
use warnings;

use File::Find qw(find);
use File::Path qw(make_path);
use File::Spec;
use Getopt::Long qw(GetOptions);
use JSON::PP qw(encode_json);
use Module::Metadata;

my @lib_dirs;
my $output_dir;
my $label = 'installed';

GetOptions(
    'lib=s@'       => \@lib_dirs,
    'output-dir=s' => \$output_dir,
    'label=s'      => \$label,
) or die "Usage: $0 --lib <path> [--lib <path> ...] --output-dir <path> [--label <name>]\n";

die "At least one --lib directory is required\n" unless @lib_dirs;
die "--output-dir is required\n" unless defined $output_dir;

my %modules;

sub normalize_module_name {
    my ($relative_path) = @_;

    my @parts = File::Spec->splitdir($relative_path);
    return undef unless @parts;

    my $filename = pop @parts;
    return undef unless $filename =~ /\.pm\z/;
    $filename =~ s/\.pm\z//;

    while (@parts && ($parts[0] !~ /\A[A-Za-z_]/ || $parts[0] =~ /-/)) {
        shift @parts;
    }

    return undef if grep { $_ !~ /\A[A-Za-z_][A-Za-z0-9_]*\z/ } @parts, $filename;

    return join('::', @parts, $filename);
}

for my $lib_dir (@lib_dirs) {
    next unless -d $lib_dir;

    find(
        {
            no_chdir => 1,
            wanted   => sub {
                return unless -f $_;
                return unless $_ =~ /\.pm\z/;

                my $relative_path = File::Spec->abs2rel($_, $lib_dir);
                return if $relative_path =~ /\A\.\./;

                my $module = normalize_module_name($relative_path);
                return unless defined $module;

                my $metadata = Module::Metadata->new_from_file($_, collect_pod => 0);
                my $version  = $metadata ? $metadata->version : undef;

                $modules{$module} //= {
                    module  => $module,
                    version => defined $version ? "$version" : q[],
                    file    => $relative_path,
                };

                if (!$modules{$module}{version} && defined $version) {
                    $modules{$module}{version} = "$version";
                }
            },
        },
        $lib_dir,
    );
}

make_path($output_dir) unless -d $output_dir;

my @module_list = map { $modules{$_} } sort keys %modules;
my $tsv_path  = File::Spec->catfile($output_dir, "$label-modules.tsv");
my $json_path = File::Spec->catfile($output_dir, "$label-modules.json");
my $txt_path  = File::Spec->catfile($output_dir, "$label-summary.txt");

open(my $tsv_fh, '>', $tsv_path) or die "Cannot open $tsv_path: $!";
print {$tsv_fh} "module\tversion\tfile\n";
for my $entry (@module_list) {
    print {$tsv_fh} join("\t", $entry->{module}, $entry->{version}, $entry->{file}) . "\n";
}
close($tsv_fh) or die "Cannot close $tsv_path: $!";

open(my $json_fh, '>', $json_path) or die "Cannot open $json_path: $!";
print {$json_fh} encode_json(
    {
        label        => $label,
        module_count => scalar @module_list,
        lib_dirs     => \@lib_dirs,
        modules      => \@module_list,
    }
) . "\n";
close($json_fh) or die "Cannot close $json_path: $!";

open(my $txt_fh, '>', $txt_path) or die "Cannot open $txt_path: $!";
print {$txt_fh} "Label: $label\n";
print {$txt_fh} "Module count: " . scalar(@module_list) . "\n";
print {$txt_fh} "Library roots:\n";
for my $lib_dir (@lib_dirs) {
    print {$txt_fh} " - $lib_dir\n";
}
close($txt_fh) or die "Cannot close $txt_path: $!";
