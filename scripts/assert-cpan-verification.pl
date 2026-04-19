#!/bin/perl
use strict;
use warnings;

use Getopt::Long qw(GetOptions);
use JSON::PP qw(decode_json);

my @reports;
my @status_files;

GetOptions(
    'report=s@'      => \@reports,
    'status-file=s@' => \@status_files,
) or die "Usage: $0 --report <path> [--report <path> ...]\n";

die "At least one --report or --status-file is required\n" unless @reports || @status_files;

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

for my $status_file (@status_files) {
    open( my $fh, '<', $status_file ) or die "Cannot open $status_file: $!";
    my $content = do { local $/; <$fh> };
    close($fh) or die "Cannot close $status_file: $!";

    my ($install_exit_code) = $content =~ /^exit_code=(\d+)/m;
    next unless defined $install_exit_code;

    if ( $install_exit_code != 0 ) {
        warn "$status_file recorded cpm install exit code $install_exit_code\n";
        $exit_code = 1;
    }
}

exit $exit_code;
