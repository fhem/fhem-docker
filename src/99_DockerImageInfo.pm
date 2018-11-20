##############################################
# $Id: 99_DockerImageInfo.pm 00000 2018-07-27 00:00:00Z loredo $
package main;

use strict;
use warnings;

sub DockerImageInfo_Initialize($) {
    my ($hash) = @_;

    $hash->{DefFn}    = "DockerImageInfo_Define";
    $hash->{AttrList} = $readingFnAttributes;
}

###################################
sub DockerImageInfo_Define($$) {
    my ( $hash, $def ) = @_;
    my @a = split( "[ \t][ \t]*", $def );

    return "Wrong syntax: use define <name> DockerImageInfo"
      if ( int(@a) != 2 );

    return "This module may only be defined once, existing device: "
      . $modules{ $hash->{TYPE} }{defptr}{NAME}
      if ( defined( $modules{ $hash->{TYPE} }{defptr} ) );

    # create global unique device definition
    $modules{ $hash->{TYPE} }{defptr} = $hash;

    return undef;
}

sub DockerImageInfo_GetImageInfo() {
    my $n = 'DockerImageInfo';

    if ( defined( $modules{'DockerImageInfo'}{defptr} ) ) {
        $n = $modules{'DockerImageInfo'}{defptr}{NAME};
    }
    else {
        fhem "defmod $n DockerImageInfo";
    }

    $defs{$n}{STATE} = 'ok';
    readingsBeginUpdate( $defs{$n} );

    my @LINES = split( "\n",
        `sort -k1,1 -t'=' --stable --unique /image_info.* /image_info`
    );

    foreach my $LINE (@LINES) {
        next unless ( $LINE =~ /^org\.opencontainers\..+=.+$/ );
        my @NV = split( "=", $LINE );
        my $NAME = shift @NV;
        $NAME =~ s/^org\.opencontainers\.//;
        my $VAL = join( "=", @NV );
        next if ( $NAME eq "image.authors" );
        readingsBulkUpdateIfChanged( $defs{$n}, $NAME, $VAL );
    }

    readingsBulkUpdateIfChanged( $defs{$n}, "ssh-id_ed25519.pub",  `cat ./.ssh/id_ed25519.pub` );
    readingsBulkUpdateIfChanged( $defs{$n}, "ssh-id_rsa.pub", `cat ./.ssh/id_rsa.pub` );

    readingsEndUpdate( $defs{$n}, 1 );
    return undef;
}

1;

=pod
=item helper
=item summary    DockerImageInfo device
=item summary_DE DockerImageInfo Ger&auml;t
=begin html

<a name="DockerImageInfo"></a>
<h3>DockerImageInfo</h3>
<ul>

  Show infos about the Docker image FHEM is running in.
  Only works together with the fhem-docker image from https://hub.docker.com/r/fhem/fhem/ .
  <br><br>

  <a name="DockerImageInfodefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; DockerImageInfo</code>
    <br><br>

    Example:
    <ul>
      <code>define DockerImageInfo DockerImageInfo</code>
    </ul>
  </ul>
  <br>

</ul>

=end html

=begin html_DE

<a name="DockerImageInfo"></a>
<h3>DockerImageInfo</h3>
<ul>

  Zeigt Informationen &uuml;ber das Docker Image, in dem FHEM gerade l&auml;ft.
  Funktioniert nur mit dem fhem-docker image von https://hub.docker.com/r/fhem/fhem/ .
  <br><br>

  <a name="DockerImageInfodefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; DockerImageInfo</code>
    <br><br>

    Example:
    <ul>
      <code>define DockerImageInfo DockerImageInfo</code>
    </ul>
  </ul>
  <br>

</ul>

=end html_DE

=cut
