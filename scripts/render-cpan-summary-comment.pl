#!/bin/perl
use strict;
use warnings;

use File::Find ();
use Getopt::Long qw(GetOptions);
use JSON::PP qw(decode_json);

# Renders the single pull request comment that summarizes the whole cpan_build
# matrix. Every matrix leg uploads one status JSON written by
# scripts/assert-cpan-verification.pl; this script merges them into one verdict
# so a pull request never collects more than one CPAN comment.

# Must stay in sync with COMMENT_MARKER in .github/workflows/build.yml and stay
# prefixed with LEGACY_MARKER_PREFIX from the same file: the workflow first
# filters bot comments by that prefix and only then looks for this marker, so a
# marker that drops the prefix makes every run post a new comment instead of
# updating the existing one. It is also quoted in docs/developer-notes.md.
my $marker = '<!-- cpan-build-report:summary -->';

my $status_dir = q[];
my $job_result = q[];
my $run_url    = q[];

GetOptions(
    'status-dir=s' => \$status_dir,
    'job-result=s' => \$job_result,
    'run-url=s'    => \$run_url,
) or die "Usage: $0 --status-dir <path> [--job-result <result>] [--run-url <url>]\n";

die "--status-dir is required\n" unless $status_dir ne q[];

sub slurp {
    my ($path) = @_;
    open( my $fh, '<', $path ) or die "Cannot open $path: $!";
    my $content = do { local $/; <$fh> };
    close($fh) or die "Cannot close $path: $!";
    return $content;
}

sub collect_status_files {
    my ($root) = @_;
    return () unless -d $root;

    my @files;
    File::Find::find(
        {
            no_chdir => 1,
            wanted   => sub {
                push @files, $File::Find::name
                  if -f $File::Find::name && !-l $File::Find::name && /\.json\z/;
            },
        },
        $root
    );
    return sort @files;
}

sub load_entry {
    my ($path) = @_;

    my $data;
    eval {
        $data = decode_json( slurp($path) );
        1;
    } or return {
        dockerfile => '(unknown)',
        platform   => '(unknown)',
        status     => 'unknown',
        reasons    => ["unreadable status file $path"],
    };

    $data->{dockerfile} = '(unknown)' unless defined $data->{dockerfile} && $data->{dockerfile} ne q[];
    $data->{platform}   = '(unknown)' unless defined $data->{platform}   && $data->{platform} ne q[];
    $data->{status}     = 'unknown'   unless defined $data->{status}     && $data->{status} ne q[];
    $data->{reasons} = [] unless ref $data->{reasons} eq 'ARRAY';
    return $data;
}

# Artifact content is never trusted for markdown: a stray pipe would break the
# table and a mention or link would turn the comment into a delivery vehicle.
sub md_cell {
    my ($value) = @_;
    $value = defined $value ? "$value" : q[];
    $value =~ s/\s+/ /g;
    $value =~ s/[`\\]//g;
    $value =~ s/([|<>\[\]\@])/\\$1/g;
    $value = substr( $value, 0, 200 ) . '...' if length($value) > 200;
    return $value;
}

sub status_cell {
    my ($status) = @_;
    return '✅ ok'      if $status eq 'ok';
    return '❌ failed'  if $status eq 'failed';
    return '⚠️ unknown';
}

sub details_for {
    my ($entry) = @_;
    my @reasons = @{ $entry->{reasons} };
    return '–' unless @reasons;

    # Matches $reasons_shown in scripts/assert-cpan-verification.pl, which caps
    # the list this reads.
    my $limit = @reasons > 3 ? 3 : scalar @reasons;
    my $text = join( '; ', map { md_cell($_) } @reasons[ 0 .. $limit - 1 ] );

    # The producer already caps the list, so trust its count of what it dropped.
    my $reason_count = $entry->{reasons_total};
    $reason_count = scalar @reasons unless defined $reason_count && $reason_count >= @reasons;
    $text .= ' (+' . ( $reason_count - $limit ) . ' more)' if $reason_count > $limit;
    return $text;
}

my @entries = map { load_entry($_) } collect_status_files($status_dir);

@entries = sort {
         $a->{dockerfile} cmp $b->{dockerfile}
      || $a->{platform} cmp $b->{platform}
} @entries;

my $total   = scalar @entries;
my $ok      = grep { $_->{status} eq 'ok' } @entries;
my $failed  = grep { $_->{status} eq 'failed' } @entries;
my $unknown = $total - $ok - $failed;

print "$marker\n";
print "## CPAN Build Report\n\n";

if ( !$total ) {
    my $result = $job_result ne q[] ? $job_result : 'unknown';
    print "⚠️ **No CPAN build results were reported.** The `cpan_build` job finished with result `$result`.\n\n";
    print "See the [workflow run]($run_url) for details.\n" if $run_url ne q[];

    # 3 rather than 2, because perl itself exits 2 when it cannot find a script:
    # the caller must be able to tell "nothing to report" from "renderer broken".
    exit 3;
}

my $all_good = ( $failed == 0 && $unknown == 0 );

if ($all_good) {
    print "✅ **All CPAN builds are fine** — $ok of $total image/platform combinations verified successfully.\n\n";
}
else {
    my @problems;
    push @problems, "$failed failed"   if $failed;
    push @problems, "$unknown unknown" if $unknown;
    print '❌ **CPAN verification reported problems** — '
      . join( ', ', @problems )
      . " of $total image/platform combinations.\n\n";
}

my $table = "| Image | Platform | Result | Details |\n| --- | --- | --- | --- |\n";
for my $entry (@entries) {
    $table .= '| `'
      . md_cell( $entry->{dockerfile} ) . '` | `'
      . md_cell( $entry->{platform} ) . '` | '
      . status_cell( $entry->{status} ) . ' | '
      . details_for($entry) . " |\n";
}

# A green run only needs the headline, so the per-image table stays collapsed.
if ($all_good) {
    print "<details>\n<summary>Per image details</summary>\n\n";
    print $table;
    print "\n</details>\n\n";
}
else {
    print $table . "\n";
}

my $artifact_hint = 'Full inventories, logs and per-image reports are available as workflow artifacts';
$artifact_hint .= " of the [workflow run]($run_url)" if $run_url ne q[];
print "$artifact_hint.\n";
