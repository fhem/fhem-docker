#!/bin/perl
use strict;
use warnings;
use CPAN::Meta;
use Module::CPANfile;
use Data::Dumper;
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

sub merge_hashes {
    my ($hash1, $hash2) = @_;
    for my $key (keys %$hash2) {
        if (ref $hash2->{$key} eq 'HASH' && ref $hash1->{$key} eq 'HASH') {
            merge_hashes($hash1->{$key}, $hash2->{$key});
        } else {
            $hash1->{$key} = $hash2->{$key};
        }
    }
    return $hash1;
}


#my $newCPANFile;
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

        

        # fix missing version information

       
        my $cpanfile_requirements = $cpanfile->prereq_specs;            # requirements from our cpanfile
        my $module_requirements = $MetaHash->{'prereqs'};               # requirements from the processed file
        # print Dumper $cpanfile_requirements;                
        # print Dumper $module_requirements;                
        
        # merge requirements together
        my $struct = merge_hashes($cpanfile_requirements, $module_requirements);
        # print Dumper $struct;              
        
        $cpanfile = Module::CPANfile->from_prereqs(  $struct );         # update cpanfile object
        print qq[$filename was processed successfull\n];
    }
}

# save our new cpanfile
if (defined $cpanfile)
{
    $cpanfile->save('cpanfile');
    print qq[\n\nResult: cpanfile was saved\n];
}


# example usage
# perl scripts/parse-METAJson.pl src/FHEM/trunk/fhem/FHEM/ 3rdParty/
#