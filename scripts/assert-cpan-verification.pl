#!/bin/perl
use strict;
use warnings;

use Getopt::Long qw(GetOptions);
use JSON::PP qw(decode_json);

my @reports;
my @status_files;
my $status_json = q[];
my $dockerfile  = q[];
my $platform    = q[];

GetOptions(
    'report=s@'      => \@reports,
    'status-file=s@' => \@status_files,
    'status-json=s'  => \$status_json,
    'dockerfile=s'   => \$dockerfile,
    'platform=s'     => \$platform,
) or die "Usage: $0 --report <path> [--report <path> ...] --status-file <path> [--status-file <path> ...] [--status-json <path> --dockerfile <name> --platform <name>]\n";

die "At least one --report or --status-file is required\n" unless @reports || @status_files;

sub shorten {
    my ($text) = @_;
    return q[] unless defined $text;
    $text =~ s/\s+/ /g;
    return length($text) > 220 ? substr( $text, 0, 217 ) . '...' : $text;
}

sub read_file {
    my ($path) = @_;
    open( my $fh, '<', $path ) or return ( undef, "Cannot open $path: $!" );
    my $content = do { local $/; <$fh> };
    close($fh) or return ( undef, "Cannot close $path: $!" );
    return ( $content, undef );
}

sub entry_line {
    my ($entry) = @_;
    my $text = $entry->{module} // 'unknown';
    $text .= ' required ' . $entry->{required} if defined $entry->{required} && $entry->{required} ne q[];
    $text .= ' installed ' . $entry->{installed} if defined $entry->{installed} && $entry->{installed} ne q[];

    if ( my $hits = $entry->{log_hits} ) {
        $text .= ' via ' . shorten( $hits->[0] ) if @{$hits};
    }
    elsif ( defined $entry->{load_error} && $entry->{load_error} ne q[] ) {
        $text .= ' load error ' . shorten( $entry->{load_error} );
    }

    return $text;
}

sub append_report_entries {
    my ( $lines, $title, $entries ) = @_;
    return unless @{$entries};

    push @{$lines}, "$title:";
    my $limit = @{$entries} > 10 ? 10 : scalar @{$entries};
    for my $idx ( 0 .. $limit - 1 ) {
        push @{$lines}, '  - ' . entry_line( $entries->[$idx] );
    }
    push @{$lines}, '  - ... and ' . ( @{$entries} - $limit ) . ' more' if @{$entries} > $limit;
}

# Counters that feed the aggregated pull request comment rendered by
# scripts/render-cpan-summary-comment.pl.
my %totals = (
    requirements              => 0,
    missing_probable_failures => 0,
    unresolved_requirements   => 0,
    version_mismatches        => 0,
    perl_version_mismatches   => 0,
    install_failures          => 0,
    reports_read              => 0,
);
my @reasons;
my $reasons_total = 0;

sub add_reason {
    my ($reason) = @_;
    $reasons_total++;
    push @reasons, $reason if @reasons < 6;
    return;
}

my @output;
my $exit_code = 0;
for my $report (@reports) {
    my ( $content, $read_error ) = read_file($report);
    if ($read_error) {
        push @output, $read_error;
        add_reason("cannot read $report");
        $exit_code = 1;
        next;
    }

    my $data;
    eval {
        $data = decode_json($content);
        1;
    } or do {
        push @output, "Cannot decode $report: $@";
        add_reason("cannot decode $report");
        $exit_code = 1;
        next;
    };

    $totals{reports_read}++;

    my $summary = $data->{summary} // {};
    my $label   = $data->{label} // $report;

    $totals{requirements}              += ( $summary->{requirements}              // 0 );
    $totals{missing_probable_failures} += ( $summary->{missing_probable_failures} // 0 );
    $totals{unresolved_requirements}   += ( $summary->{unresolved_requirements}   // 0 );
    $totals{version_mismatches}        += ( $summary->{version_mismatches}        // 0 );
    $totals{perl_version_mismatches}   += ( $summary->{perl_version_mismatches}   // 0 );

    my $bad = ( $summary->{missing_probable_failures} // 0 )
      + ( $summary->{version_mismatches} // 0 )
      + ( $summary->{perl_version_mismatches} // 0 );

    if ($bad) {
        push @output, "$report has $bad actionable verification failures";
        push @output,
          "$label summary: requirements=" . ( $summary->{requirements} // 0 )
          . ', missing_probable_install_failures=' . ( $summary->{missing_probable_failures} // 0 )
          . ', unresolved_requirements=' . ( $summary->{unresolved_requirements} // 0 )
          . ', version_mismatches=' . ( $summary->{version_mismatches} // 0 )
          . ', perl_version_mismatches=' . ( $summary->{perl_version_mismatches} // 0 );
        append_report_entries( \@output, 'Missing probable install failures', $data->{missing_probable_install_failures} // [] );
        append_report_entries( \@output, 'Version mismatches',               $data->{version_mismatches} // [] );
        append_report_entries( \@output, 'Perl version mismatches',          $data->{perl_version_mismatches} // [] );
        add_reason("$label: $bad actionable verification failures");
        $exit_code = 1;
    }
}

for my $status_file (@status_files) {
    my ( $content, $read_error ) = read_file($status_file);
    if ($read_error) {
        push @output, $read_error;
        add_reason("cannot read $status_file");
        $exit_code = 1;
        next;
    }

    my ($install_exit_code) = $content =~ /^exit_code=(\d+)/m;
    next unless defined $install_exit_code;

    if ( $install_exit_code != 0 ) {
        push @output, "$status_file recorded cpm install exit code $install_exit_code";
        $totals{install_failures}++;
        my $label = $status_file =~ m{/([^/]+)-install-status\.txt\z} ? $1 : $status_file;
        add_reason("$label: cpm install exit code $install_exit_code");
        $exit_code = 1;
    }
}

if (@output) {
    print "CPAN verification failed:\n";
    print "$_\n" for @output;

    if ( my $summary_path = $ENV{GITHUB_STEP_SUMMARY} ) {
        if ( open( my $summary_fh, '>>', $summary_path ) ) {
            print {$summary_fh} "\n## CPAN verification assert\n\n";
            print {$summary_fh} "The CPAN verification assert found actionable failures:\n\n";
            print {$summary_fh} "- $_\n" for @output;
            close($summary_fh) or warn "Cannot close $summary_path: $!";
        }
        else {
            warn "Cannot open $summary_path: $!";
        }
    }
}

if ( $status_json ne q[] ) {
    my $encoder = JSON::PP->new->canonical->pretty;
    my $payload = {
        dockerfile => $dockerfile,
        platform   => $platform,
        status     => $exit_code == 0 ? 'ok' : 'failed',
        reasons    => \@reasons,
        reasons_total => $reasons_total,
        totals        => \%totals,
    };

    open( my $status_fh, '>', $status_json ) or die "Cannot open $status_json: $!\n";
    print {$status_fh} $encoder->encode($payload);
    close($status_fh) or die "Cannot close $status_json: $!\n";
}

exit $exit_code;
