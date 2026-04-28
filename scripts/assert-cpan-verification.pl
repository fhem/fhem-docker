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
) or die "Usage: $0 --report <path> [--report <path> ...] --status-file <path> [--status-file <path> ...]\n";

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

my @output;
my $exit_code = 0;
for my $report (@reports) {
    my ( $content, $read_error ) = read_file($report);
    if ($read_error) {
        push @output, $read_error;
        $exit_code = 1;
        next;
    }

    my $data;
    eval {
        $data = decode_json($content);
        1;
    } or do {
        push @output, "Cannot decode $report: $@";
        $exit_code = 1;
        next;
    };

    my $summary = $data->{summary} // {};
    my $bad = ( $summary->{missing_probable_failures} // 0 )
      + ( $summary->{version_mismatches} // 0 )
      + ( $summary->{perl_version_mismatches} // 0 );

    if ($bad) {
        my $label = $data->{label} // $report;
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
        $exit_code = 1;
    }
}

for my $status_file (@status_files) {
    my ( $content, $read_error ) = read_file($status_file);
    if ($read_error) {
        push @output, $read_error;
        $exit_code = 1;
        next;
    }

    my ($install_exit_code) = $content =~ /^exit_code=(\d+)/m;
    next unless defined $install_exit_code;

    if ( $install_exit_code != 0 ) {
        push @output, "$status_file recorded cpm install exit code $install_exit_code";
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

exit $exit_code;
