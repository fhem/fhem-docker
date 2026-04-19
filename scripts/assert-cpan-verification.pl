#!/bin/perl
use strict;
use warnings;

use Getopt::Long qw(GetOptions);
use JSON::PP qw(decode_json);

my @reports;

GetOptions(
    'report=s@' => \@reports,
) or die "Usage: $0 --report <path> [--report <path> ...]\n";

die "At least one --report is required\n" unless @reports;

my $exit_code = 0;
for my $report (@reports) {
    open( my $fh, '<', $report ) or die "Cannot open $report: $!";
    my $data = decode_json( do { local $/; <$fh> } );
    close($fh) or die "Cannot close $report: $!";

    my $summary = $data->{summary} // {};
    my $bad = ( $summary->{missing_probable_failures} // 0 )
      + ( $summary->{version_mismatches} // 0 )
      + ( $summary->{perl_version_mismatches} // 0 );

    if ($bad) {
        warn "$report has $bad actionable verification failures\n";
        $exit_code = 1;
    }
}

exit $exit_code;
