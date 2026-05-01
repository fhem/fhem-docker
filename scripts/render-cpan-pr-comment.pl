#!/bin/perl
use strict;
use warnings;

use Getopt::Long qw(GetOptions);
use JSON::PP qw(decode_json);

my $dockerfile = q[];
my $platform   = q[];
my $artifact   = q[];
my @reports;
my @logs;
my @status_files;

GetOptions(
    'dockerfile=s'   => \$dockerfile,
    'platform=s'     => \$platform,
    'artifact=s'     => \$artifact,
    'report=s@'      => \@reports,
    'log=s@'         => \@logs,
    'status-file=s@' => \@status_files,
) or die "Usage: $0 --dockerfile <name> --platform <name> [--artifact <name>] --report <path> [--report <path> ...] [--log <path> ...] [--status-file <path> ...]\n";

sub slurp {
    my ($path) = @_;
    open( my $fh, '<', $path ) or die "Cannot open $path: $!";
    my $content = do { local $/; <$fh> };
    close($fh) or die "Cannot close $path: $!";
    return $content;
}

sub trim {
    my ($value) = @_;
    $value //= q[];
    $value =~ s/^\s+//;
    $value =~ s/\s+$//;
    return $value;
}

sub shorten {
    my ($value) = @_;
    $value = trim($value);
    return $value if length($value) <= 180;
    return substr( $value, 0, 177 ) . '...';
}

sub summarize_entries {
    my ( $title, $entries, $formatter ) = @_;
    return q[] unless @{$entries};

    my $body = "#### $title\n";
    my $limit = @{$entries} > 8 ? 8 : scalar @{$entries};
    for my $idx ( 0 .. $limit - 1 ) {
        $body .= '- ' . $formatter->( $entries->[$idx] ) . "\n";
    }
    if ( @{$entries} > $limit ) {
        $body .= '- ... and ' . ( @{$entries} - $limit ) . " more\n";
    }
    return $body . "\n";
}

sub read_status_notes {
    my ($path) = @_;
    return () unless -f $path;

    my @notes;
    for my $line ( split /\n/, slurp($path) ) {
        next unless $line =~ /\A([^=]+)=(\d+)\z/;
        push @notes, "`$1=$2`" if $2 ne '0';
    }
    return @notes;
}

sub normalize_platform {
    my ($value) = @_;
    return 'linux/' . $value unless $value =~ m{\Alinux/};
    return $value;
}

sub excluded_requirements_for {
    my ( $dockerfile_name, $platform_name ) = @_;
    my $target = normalize_platform($platform_name);

    my @core;
    my @thirdparty;

    if ( $target ne 'linux/amd64' && $target ne 'linux/386' ) {
        push @core,       'Device::Firmata::Constants';
        push @thirdparty, 'Device::Firmata::Constants';
    }

    if ( $target eq 'linux/386' ) {
        push @core, 'Math::Pari', 'Crypt::Random';
    }

    if ( $target ne 'linux/amd64' ) {
        push @core, 'HiPi';
    }

    my $is_bookworm = $dockerfile_name =~ /bookworm/;
    if (
        ( $is_bookworm && ( $target eq 'linux/arm/v7' || $target eq 'linux/386' || $target eq 'linux/arm64' ) )
        || ( !$is_bookworm && $target eq 'linux/arm/v7' )
      )
    {
        push @thirdparty, 'SNMP';
    }

    return ( \@core, \@thirdparty );
}

sub print_excluded_requirements {
    my ( $core_excluded, $thirdparty_excluded ) = @_;
    return unless @{$core_excluded} || @{$thirdparty_excluded};

    print "### Excluded CPAN requirements for this image\n";
    if ( @{$core_excluded} ) {
        print "- `core`: " . join( ', ', map { "`$_`" } @{$core_excluded} ) . "\n";
    }
    if ( @{$thirdparty_excluded} ) {
        print "- `3rdparty`: " . join( ', ', map { "`$_`" } @{$thirdparty_excluded} ) . "\n";
    }
    print "\n";
}

sub extract_failure_candidates {
    my ($path) = @_;
    return [] unless -f $path;

    my @candidates;
    my $collect = 0;
    for my $line ( split /\n/, slurp($path) ) {
        if ( $line =~ /Installation failed\.\s+The direct cause of the failure/ ) {
            $collect = 1;
            next;
        }
        next unless $collect;
        if ( $line =~ /\|\s+\*\s+(.+?)\s*\z/ ) {
            push @candidates, trim($1);
            next;
        }
        $collect = 0 if $line !~ /\|\s+\*\s+/;
    }
    return \@candidates;
}

sub extract_failed_distributions {
    my ($path) = @_;
    return [] unless -f $path;

    my @distributions;
    for my $line ( split /\n/, slurp($path) ) {
        next unless $line =~ /,([^,|]+)\|\s+Failed to install distribution\b/i;
        push @distributions, trim($1);
    }
    return \@distributions;
}

my @status_notes;
for my $status_file (@status_files) {
    push @status_notes, read_status_notes($status_file);
}

print "<!-- cpan-build-report:$dockerfile:$platform -->\n";
print "## CPAN Build Report `$dockerfile` / `$platform`\n\n";
print "Artifact: `$artifact`\n\n" if $artifact ne q[];

my ( $core_excluded, $thirdparty_excluded ) = excluded_requirements_for( $dockerfile, $platform );
print_excluded_requirements( $core_excluded, $thirdparty_excluded );

if (@status_notes) {
    print "Detected non-zero `cpm install` exit codes: " . join( ', ', @status_notes ) . "\n\n";
}

for my $log_path (@logs) {
    next unless @status_notes;

    my $failed_distributions = extract_failed_distributions($log_path);
    if (@{$failed_distributions}) {
        my $label = $log_path =~ /3rdparty/ ? '3rdparty' : 'core';
        print "### Failed distributions in `$label`\n";
        my $limit = @{$failed_distributions} > 12 ? 12 : scalar @{$failed_distributions};
        for my $idx ( 0 .. $limit - 1 ) {
            print '- `' . $failed_distributions->[$idx] . "`\n";
        }
        if ( @{$failed_distributions} > $limit ) {
            print '- ... and ' . ( @{$failed_distributions} - $limit ) . " more\n";
        }
        print "\n";
    }

    my $candidates = extract_failure_candidates($log_path);
    next unless @{$candidates};

    my $label = $log_path =~ /3rdparty/ ? '3rdparty' : 'core';
    print "### `cpm` direct failure candidates in `$label`\n";
    my $limit = @{$candidates} > 12 ? 12 : scalar @{$candidates};
    for my $idx ( 0 .. $limit - 1 ) {
        print '- `' . $candidates->[$idx] . "`\n";
    }
    if ( @{$candidates} > $limit ) {
        print '- ... and ' . ( @{$candidates} - $limit ) . " more\n";
    }
    print "\n";
}

my $report_found = 0;
for my $report_path (@reports) {
    next unless -f $report_path;
    $report_found = 1;

    my $data    = decode_json( slurp($report_path) );
    my $label   = $data->{label}   // 'unknown';
    my $summary = $data->{summary} // {};

    print "### `$label`\n";
    print '- Requirements: ' . ( $summary->{requirements} // 0 ) . "\n";
    print '- Satisfied from local libs: ' . ( $summary->{satisfied_local} // 0 ) . "\n";
    print '- Satisfied from core/base: ' . ( $summary->{satisfied_core_or_base} // 0 ) . "\n";
    print '- Missing probable install failures: ' . ( $summary->{missing_probable_failures} // 0 ) . "\n";
    print '- Unresolved requirements: ' . ( $summary->{unresolved_requirements} // 0 ) . "\n";
    print '- Version mismatches: ' . ( $summary->{version_mismatches} // 0 ) . "\n\n";

    print summarize_entries(
        'Missing probable install failures',
        $data->{missing_probable_install_failures} // [],
        sub {
            my ($entry) = @_;
            my $text = '`' . ( $entry->{module} // 'unknown' ) . '`';
            $text .= ' required `' . $entry->{required} . '`' if defined $entry->{required} && $entry->{required} ne q[];
            if ( my $hits = $entry->{log_hits} ) {
                $text .= ' via `' . shorten( $hits->[0] ) . '`' if @{$hits};
            }
            return $text;
        }
    );

    print summarize_entries(
        'Unresolved requirements',
        $data->{unresolved_requirements} // [],
        sub {
            my ($entry) = @_;
            my $text = '`' . ( $entry->{module} // 'unknown' ) . '`';
            $text .= ' required `' . $entry->{required} . '`' if defined $entry->{required} && $entry->{required} ne q[];
            $text .= ' load error `' . shorten( $entry->{load_error} ) . '`' if defined $entry->{load_error} && $entry->{load_error} ne q[];
            return $text;
        }
    );

    print summarize_entries(
        'Version mismatches',
        $data->{version_mismatches} // [],
        sub {
            my ($entry) = @_;
            return '`' . ( $entry->{module} // 'unknown' ) . '` required `'
              . ( $entry->{required} // q[] ) . '` but found `'
              . ( $entry->{installed} // q[] ) . '`';
        }
    );
}

print "No exported CPAN verification reports were found for this matrix run.\n" unless $report_found;
