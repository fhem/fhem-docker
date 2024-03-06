#!/bin/perl
use strict;
use warnings;
use CPAN::Meta;
use Module::CPANfile;
# use Data::Dumper;
use CPAN::Meta::Merge;
use Scalar::Util qw/blessed/;
use File::Find::Rule;
use JSON;

my @directories = @ARGV;

#my $filename = @ARGV # path must be provided to our script
my @JSONlines;
my $jsonString;
#my $line;
## Load existing requirements from cpanfile
my $cpanfile = Module::CPANfile->load('cpanfile');

my $newCPANFile;
# Alle Perl-Moduldateien im Verzeichnisbaum finden
foreach my $directory (@directories) {


    my @files = File::Find::Rule->file()->name('*.pm')->in($directory);

    foreach my $filename (@files) {
        $jsonString="";
        @JSONlines=();

        print qq[\n try processing file $filename ...];
        open(my $fh, '<', $filename) or die "can not open file: $!";
        my $inside_for = 0;

        while (<$fh>) {
            if (/^=for :application\/json;q=META.json/) {
                $inside_for = 1;
                next;
            }
            if ($inside_for) {
                last if /^=end :application\/json;q=META.json/;  # Ende des =for-Abschnitts
                $_ =~ s/\R//g;

                push @JSONlines, $_;
            
            }
        }
        close($fh);
        if (!@JSONlines)
        {
            print "aborting, no META.json found\n";
            next;
        }

        $jsonString = join '', @JSONlines;

        ## Script breaks here, because we may have no version field which is requred to pass here
        
        my $MetaHash;
        eval {
            $MetaHash = from_json($jsonString) ;
            1;
        } or do {
                print q[[ failed ]]. $@;
                next;
        };

        #print Dumper $MetaHash;

        # fix missing version information
        my @fixups = ();

        if (!exists($MetaHash->{version}) )
        {
            push(@fixups, q[version] );

            $MetaHash->{version} = "1";
            
        }
        if (!exists($MetaHash->{name}) )
        {
            push(@fixups, q[name] );
            $MetaHash->{name} = $filename;
        }

        if (!exists($MetaHash->{'meta-spec'}) || !exists($MetaHash->{'meta-spec'}{'version'})  )
        {
            push(@fixups, q[meta-spec] );
            $MetaHash->{'meta-spec'}{'version'} = 2;
        }

        if (scalar @fixups > 0)
        {
            print q[ fixups: ];
            print join ", ", @fixups;
            print q[ ];
        }


        my $moduleMeta;
        eval {
            $moduleMeta = CPAN::Meta->load_json_string(to_json($MetaHash));
            1;
        } or do {
                print q[[ failed ]]. $@;
                next;
        };
        

        # merge requirements
       
        my $prereqs_hash = $cpanfile->prereqs->with_merged_prereqs($moduleMeta->effective_prereqs)->as_string_hash;
        my $struct = { %{$moduleMeta->as_struct}, prereqs => $prereqs_hash };
        
        #print $moduleMeta->meta_spec->{version};

        my $mergedMeta =  CPAN::Meta->new($struct);
        $newCPANFile = Module::CPANfile->from_prereqs(  $mergedMeta->prereqs );
      
        $cpanfile = $newCPANFile;
        print qq[$filename was processed successfull\n];
    }
}

# save our new cpanfile
if (defined $newCPANFile)
{
    $newCPANFile->save('cpanfile');
    print qq[\n\nResult: cpanfile was saved\n];
}


# example usage
# perl scripts/parse-METAJson.pl src/FHEM/trunk/fhem/FHEM/ 3rdParty/
#