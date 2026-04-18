#!/bin/perl
use strict;
use warnings;

use File::Path qw(make_path);
use Getopt::Long qw(GetOptions);
use JSON::PP qw(decode_json encode_json);
use Module::CPANfile;
use version ();

my @cpanfiles;
my $installed_json;
my $output_dir;
my $label = 'comparison';

GetOptions(
    'cpanfile=s@'      => \@cpanfiles,
    'installed-json=s' => \$installed_json,
    'output-dir=s'     => \$output_dir,
    'label=s'          => \$label,
) or die "Usage: $0 --cpanfile <path> [--cpanfile <path> ...] --installed-json <path> --output-dir <path> [--label <name>]\n";

die "At least one --cpanfile is required\n" unless @cpanfiles;
die "--installed-json is required\n" unless defined $installed_json;
die "--output-dir is required\n" unless defined $output_dir;

sub normalize_required_version {
    my ($value) = @_;
    return q[] unless defined $value;

    my $string = "$value";
    return q[] if $string eq '0';
    return $string;
}

sub version_satisfies {
    my ( $installed, $required ) = @_;
    return 1 if !defined $required || $required eq q[] || $required eq '0';
    return 0 if !defined $installed || $installed eq q[];

    my ($installed_obj, $required_obj);
    eval {
        $installed_obj = version->parse($installed);
        $required_obj  = version->parse($required);
        1;
    } or return $installed ge $required;

    return $installed_obj >= $required_obj;
}

my %expected;
for my $cpanfile_path (@cpanfiles) {
    my $cpanfile = Module::CPANfile->load($cpanfile_path);
    my $specs    = $cpanfile->prereq_specs;

    for my $phase ( keys %{$specs} ) {
        next unless ref $specs->{$phase} eq 'HASH';
        for my $relation ( keys %{ $specs->{$phase} } ) {
            next unless ref $specs->{$phase}{$relation} eq 'HASH';
            for my $module ( keys %{ $specs->{$phase}{$relation} } ) {
                my $required = normalize_required_version($specs->{$phase}{$relation}{$module});
                if ( !exists $expected{$module} ) {
                    $expected{$module} = $required;
                    next;
                }
                next if $expected{$module} eq $required;
                next if $required eq q[];
                if ( $expected{$module} eq q[] || !version_satisfies( $expected{$module}, $required ) ) {
                    $expected{$module} = $required;
                }
            }
        }
    }
}

open( my $installed_fh, '<', $installed_json ) or die "Cannot open $installed_json: $!";
my $installed_payload = do { local $/; <$installed_fh> };
close($installed_fh) or die "Cannot close $installed_json: $!";

my $installed_data = decode_json($installed_payload);
my %installed = map { $_->{module} => ( $_->{version} // q[] ) } @{ $installed_data->{modules} // [] };

my @missing;
my @version_mismatches;
for my $module ( sort keys %expected ) {
    if ( !exists $installed{$module} ) {
        push @missing, { module => $module, required => $expected{$module} };
        next;
    }

    next if version_satisfies( $installed{$module}, $expected{$module} );
    push @version_mismatches,
      {
        module    => $module,
        required  => $expected{$module},
        installed => $installed{$module},
      };
}

my %is_expected = map { $_ => 1 } keys %expected;
my @extra = map { { module => $_, installed => $installed{$_} } } grep { !$is_expected{$_} } sort keys %installed;

make_path($output_dir) unless -d $output_dir;

my $summary_path = "$output_dir/$label-summary.txt";
my $json_path    = "$output_dir/$label-result.json";

open( my $summary_fh, '>', $summary_path ) or die "Cannot open $summary_path: $!";
print {$summary_fh} "Label: $label\n";
print {$summary_fh} "Expected modules: " . scalar( keys %expected ) . "\n";
print {$summary_fh} "Installed modules: " . scalar( keys %installed ) . "\n";
print {$summary_fh} "Missing modules: " . scalar(@missing) . "\n";
print {$summary_fh} "Version mismatches: " . scalar(@version_mismatches) . "\n";
print {$summary_fh} "Additional installed modules: " . scalar(@extra) . "\n";
close($summary_fh) or die "Cannot close $summary_path: $!";

open( my $json_fh, '>', $json_path ) or die "Cannot open $json_path: $!";
print {$json_fh} encode_json(
    {
        label              => $label,
        expected_count     => scalar( keys %expected ),
        installed_count    => scalar( keys %installed ),
        missing            => \@missing,
        version_mismatches => \@version_mismatches,
        extra              => \@extra,
    }
) . "\n";
close($json_fh) or die "Cannot close $json_path: $!";

if ( @missing || @version_mismatches ) {
    for my $entry (@missing) {
        my $required = $entry->{required} eq q[] ? 'any' : $entry->{required};
        warn "Missing module: $entry->{module} (required: $required)\n";
    }
    for my $entry (@version_mismatches) {
        my $required = $entry->{required} eq q[] ? 'any' : $entry->{required};
        my $installed_version = $entry->{installed} eq q[] ? 'unknown' : $entry->{installed};
        warn "Version mismatch: $entry->{module} (required: $required, installed: $installed_version)\n";
    }
    exit 1;
}

exit 0;
