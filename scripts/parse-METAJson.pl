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
use Perl::PrereqScanner::NotQuiteLite::App;
use Module::CoreList;

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

sub filter_nested_hashref {
    my $hashref = shift;
    my $filter_value = shift;

    foreach my $key (keys %{$hashref}) {
        #print "verify $key \n";

        if (ref $hashref->{$key} eq 'HASH') {
            #print "$key->";
            $hashref->{$key} = filter_nested_hashref($hashref->{$key}, $filter_value);
            
            #print Dumper $hashref->{$key};
        } elsif ( $key =~ $filter_value || Module::CoreList->is_core( $key,undef,5.36) )
        {
            #print "\n Deleting $key";
            delete $hashref->{$key};
            #print "... successfull " if ( !exists $hashref->{$key} )
        } 
    }
    return $hashref;
}

#my $newCPANFile;
# Alle Perl-Moduldateien im Verzeichnisbaum finden
#print Dumper \%ENV;
my $FHEM_MODULES = $ENV{'FHEM_MODULES'} // "";
my $regex=qr/$FHEM_MODULES/;
print $regex;
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
        
        my $module_requirements;
        
        if (!@JSONlines)
        {
            print "aborting, no META.json found\n";
            next;

            # my $app = Perl::PrereqScanner::NotQuiteLite::App->new(
            #     parsers => [qw/:installed/],
            #     suggests => 1,
            #     # recommends => 1,
            #     # perl_minimum_version => 1,
            #      exclude_core => 1,
            #     private_re => $regex,                
            # );
            # my $scannedprereqs = $app->run($filename);
            # $module_requirements = $scannedprereqs->{'prereqs'};
            
        } else { 
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
            # requirements from the processed file
            $module_requirements = filter_nested_hashref($MetaHash->{'prereqs'}, $regex);
        }       
        

        # fix missing version information

        my $cpanfile_requirements = $cpanfile->prereq_specs;            # requirements from our cpanfile

        # print Dumper $module_requirements;
        # print Dumper $cpanfile_requirements;                
        # print Dumper $module_requirements;                
        
        # merge requirements together
        my $struct = merge_hashes($cpanfile_requirements, $module_requirements);
        print "struct: ";
        print Dumper $struct;        

        $cpanfile = Module::CPANfile->from_prereqs(  $struct );         # update cpanfile object
        print qq[$filename was processed successfull\n];
    }
}

# save our new cpanfile
if (defined $cpanfile)
{
    #print Dumper $cpanfile;        
    $cpanfile->save('cpanfile');
    print qq[\n\nResult: cpanfile was saved\n];
}


# example usage
# perl scripts/parse-METAJson.pl src/FHEM/trunk/fhem/FHEM/ 3rdParty/
#