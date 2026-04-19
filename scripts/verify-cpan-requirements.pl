#!/bin/perl
use strict;
use warnings;

use Config;
use File::Path qw(make_path);
use Getopt::Long qw(GetOptions);
use JSON::PP qw(decode_json encode_json);
use Module::CoreList;
use version ();

my @requirements_json;
my @cpanfiles;
my @log_files;
my @lib_dirs;
my $output_dir;
my $label = 'verification';

GetOptions(
    'requirements-json=s@' => \@requirements_json,
    'cpanfile=s@'          => \@cpanfiles,
    'log=s@'               => \@log_files,
    'lib=s@'               => \@lib_dirs,
    'output-dir=s'         => \$output_dir,
    'label=s'              => \$label,
) or die "Usage: $0 (--cpanfile <path> [--cpanfile <path> ...] | --requirements-json <path> [--requirements-json <path> ...]) --output-dir <path> [--log <path> ...] [--lib <path> ...] [--label <name>]\n";

die "At least one --cpanfile or --requirements-json is required\n" unless @requirements_json || @cpanfiles;
die "--output-dir is required\n" unless defined $output_dir;

sub compare_versions {
    my ( $left, $right ) = @_;

    my ( $left_obj, $right_obj );
    eval {
        $left_obj  = version->parse($left);
        $right_obj = version->parse($right);
        1;
    } or return $left cmp $right;

    return $left_obj <=> $right_obj;
}

sub version_matches_constraint {
    my ( $installed, $constraint ) = @_;

    if ( $constraint =~ /\A\s*(<=|>=|==|!=|<|>)\s*(.+?)\s*\z/ ) {
        my ( $operator, $required_version ) = ( $1, $2 );
        my $comparison = compare_versions( $installed, $required_version );

        return $comparison < 0  if $operator eq '<';
        return $comparison <= 0 if $operator eq '<=';
        return $comparison > 0  if $operator eq '>';
        return $comparison >= 0 if $operator eq '>=';
        return $comparison == 0 if $operator eq '==';
        return $comparison != 0 if $operator eq '!=';
    }

    return compare_versions( $installed, $constraint ) >= 0;
}

sub version_satisfies {
    my ( $installed, $required ) = @_;
    return 1 if !defined $required || $required eq q[] || $required eq '0';
    return 0 if !defined $installed || $installed eq q[];

    my @constraints = grep { $_ ne q[] } split /\s*,\s*/, $required;
    @constraints = ($required) unless @constraints;

    for my $constraint (@constraints) {
        return 0 unless version_matches_constraint( $installed, $constraint );
    }

    return 1;
}

sub slurp {
    my ($path) = @_;
    open( my $fh, '<', $path ) or die "Cannot open $path: $!";
    my $content = do { local $/; <$fh> };
    close($fh) or die "Cannot close $path: $!";
    return $content;
}

sub normalize_required {
    my ($required) = @_;
    return q[] unless defined $required;
    my $string = "$required";
    return q[] if $string eq '0';
    return $string;
}

sub find_log_hits {
    my ( $module, $logs_ref ) = @_;

    my $module_pattern = quotemeta($module);
    my $file_pattern   = quotemeta( $module =~ s{::}{/}gr ) . '\.pm';
    my @hits;

    for my $line ( @{$logs_ref} ) {
        next unless $line =~ /$module_pattern|$file_pattern/i;
        push @hits, $line;
        last if @hits >= 10;
    }

    return \@hits;
}

my %requirements;
for my $path (@cpanfiles) {
    my @lines = split /\n/, slurp($path);
    for my $line (@lines) {
        next if $line =~ /^\s*#/;
        next unless $line =~ /\b(?:requires|recommends|suggests)\s+['"]([^'"]+)['"](?:\s*,\s*['"]?([^'";]+?)['"]?)?\s*;/;

        my $module   = $1;
        my $required = normalize_required($2);
        $requirements{$module} = $required unless exists $requirements{$module};
    }
}

for my $path (@requirements_json) {
    my $data = decode_json( slurp($path) );
    for my $entry ( @{ $data->{requirements} // [] } ) {
        next unless defined $entry->{module};
        $requirements{ $entry->{module} } = normalize_required( $entry->{required} );
    }
}

my @log_lines;
for my $log_file (@log_files) {
    next unless -f $log_file;
    push @log_lines, split /\n/, slurp($log_file);
}

my @inc_prefixes = grep { defined $_ && $_ ne q[] } @lib_dirs;
local @INC = ( @inc_prefixes, @INC );

my @satisfied_local;
my @satisfied_core_or_base;
my @missing_probable_install_failures;
my @unresolved_requirements;
my @invalid_requirements;
my @version_mismatches;
my @perl_version_mismatches;

for my $module ( sort keys %requirements ) {
    my $required = $requirements{$module};

    if ( $module eq 'perl' ) {
        if ( version_satisfies( $], $required ) ) {
            push @satisfied_core_or_base,
              {
                module   => $module,
                required => $required,
                source   => 'perl-core',
                version  => "$]",
              };
        }
        else {
            push @perl_version_mismatches,
              {
                module    => $module,
                required  => $required,
                installed => "$]",
              };
        }
        next;
    }

    if ( $module !~ /\A[A-Za-z_][A-Za-z0-9_]*(?:::[A-Za-z_][A-Za-z0-9_]*)*\z/ ) {
        push @invalid_requirements,
          {
            module   => $module,
            required => $required,
            reason   => 'invalid-module-name',
          };
        next;
    }

    my $is_core = Module::CoreList::is_core( $module, undef, $] ) ? 1 : 0;
    my $load_ok = eval "require $module; 1;";
    my $load_error = $@;

    if ($load_ok) {
        my $inc_key = $module;
        $inc_key =~ s{::}{/}g;
        $inc_key .= '.pm';

        my $loaded_path = $INC{$inc_key} // q[];
        my $installed_version = eval { no strict 'refs'; my $v = $module->VERSION(); defined $v ? "$v" : q[]; };
        $installed_version = q[] if $@;

        if ( !version_satisfies( $installed_version, $required ) ) {
            push @version_mismatches,
              {
                module    => $module,
                required  => $required,
                installed => $installed_version,
                source    => $loaded_path,
              };
            next;
        }

        my $is_local = 0;
        for my $prefix (@inc_prefixes) {
            next unless defined $prefix && $prefix ne q[];
            if ( $loaded_path ne q[] && index( $loaded_path, $prefix ) == 0 ) {
                $is_local = 1;
                last;
            }
        }

        my $entry = {
            module   => $module,
            required => $required,
            version  => $installed_version,
            source   => $loaded_path,
        };

        if ($is_local) {
            push @satisfied_local, $entry;
        }
        else {
            $entry->{core} = $is_core;
            push @satisfied_core_or_base, $entry;
        }
        next;
    }

    my $log_hits = find_log_hits( $module, \@log_lines );
    my $entry = {
        module    => $module,
        required  => $required,
        core      => $is_core,
        load_error => $load_error,
        log_hits  => $log_hits,
    };

    if ( @{$log_hits} ) {
        push @missing_probable_install_failures, $entry;
    }
    else {
        push @unresolved_requirements, $entry;
    }
}

make_path($output_dir) unless -d $output_dir;

my $summary = {
    requirements                 => scalar( keys %requirements ),
    satisfied_local              => scalar @satisfied_local,
    satisfied_core_or_base       => scalar @satisfied_core_or_base,
    missing_probable_failures    => scalar @missing_probable_install_failures,
    unresolved_requirements      => scalar @unresolved_requirements,
    invalid_requirements         => scalar @invalid_requirements,
    version_mismatches           => scalar @version_mismatches,
    perl_version_mismatches      => scalar @perl_version_mismatches,
};

my $json_path    = "$output_dir/$label-result.json";
my $summary_path = "$output_dir/$label-summary.txt";

open( my $json_fh, '>', $json_path ) or die "Cannot open $json_path: $!";
print {$json_fh} encode_json(
    {
        label                            => $label,
        perl_version                     => "$]",
        archname                         => $Config{archname},
        summary                          => $summary,
        satisfied_local                  => \@satisfied_local,
        satisfied_core_or_base           => \@satisfied_core_or_base,
        missing_probable_install_failures => \@missing_probable_install_failures,
        unresolved_requirements          => \@unresolved_requirements,
        invalid_requirements             => \@invalid_requirements,
        version_mismatches               => \@version_mismatches,
        perl_version_mismatches          => \@perl_version_mismatches,
    }
) . "\n";
close($json_fh) or die "Cannot close $json_path: $!";

open( my $summary_fh, '>', $summary_path ) or die "Cannot open $summary_path: $!";
print {$summary_fh} "Label: $label\n";
print {$summary_fh} "Perl version: $]\n";
print {$summary_fh} "Requirements: $summary->{requirements}\n";
print {$summary_fh} "Satisfied from local libs: $summary->{satisfied_local}\n";
print {$summary_fh} "Satisfied from core/base: $summary->{satisfied_core_or_base}\n";
print {$summary_fh} "Missing probable install failures: $summary->{missing_probable_failures}\n";
print {$summary_fh} "Unresolved requirements: $summary->{unresolved_requirements}\n";
print {$summary_fh} "Invalid requirements: $summary->{invalid_requirements}\n";
print {$summary_fh} "Version mismatches: $summary->{version_mismatches}\n";
print {$summary_fh} "Perl version mismatches: $summary->{perl_version_mismatches}\n";
close($summary_fh) or die "Cannot close $summary_path: $!";
