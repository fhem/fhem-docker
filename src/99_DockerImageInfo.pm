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
    my $name = $hash->{NAME};

    return "Wrong syntax: use define <name> DockerImageInfo"
      if ( int(@a) != 2 );

    return "This module may only be defined once, existing device: "
      . $modules{ $hash->{TYPE} }{defptr}{NAME}
      if ( defined( $modules{ $hash->{TYPE} }{defptr} )
        && $init_done
        && !defined( $hash->{OLDDEF} ) );

    # create global unique device definition
    $modules{ $hash->{TYPE} }{defptr} = $hash;

    if ( $init_done && !defined( $hash->{OLDDEF} ) ) {

        # presets for FHEMWEB
        $attr{$name}{alias} = 'Docker Image Info';
        $attr{$name}{devStateIcon} =
'ok:security@green Initialized:system_fhem_reboot@orange .*:message_attention@red';
        $attr{$name}{group} = 'System';
        $attr{$name}{icon}  = 'docker';
        $attr{$name}{room}  = 'System';
    }

    if ( -e '/.dockerenv' ) {
        $defs{$name}{STATE} = "Initialized";
    }
    else {
        $defs{$name}{STATE} = "ERROR: Host is not a container";
    }

    return undef;
}

sub DockerImageInfo_GetImageInfo() {
    return
      unless ($init_done);
    return "undefined"
      unless ( defined( $modules{'DockerImageInfo'}{defptr} ) );
    my $n = $modules{'DockerImageInfo'}{defptr}{NAME};

    $defs{$n}{STATE} = 'ok';
    readingsBeginUpdate( $defs{$n} );

    my @LINES = split( "\n",
        `sort -k1,1 -t'=' --stable --unique /image_info.* /image_info` );

    foreach my $LINE (@LINES) {
        next unless ( $LINE =~ /^org\.opencontainers\..+=.+$/ );
        my @NV = split( "=", $LINE );
        my $NAME = shift @NV;
        $NAME =~ s/^org\.opencontainers\.//;
        my $VAL = join( "=", @NV );
        next if ( $NAME eq "image.authors" );
        readingsBulkUpdateIfChanged( $defs{$n}, $NAME, $VAL );
    }

    readingsBulkUpdateIfChanged( $defs{$n}, "ssh-id_ed25519.pub",
        `cat ./.ssh/id_ed25519.pub` );
    readingsBulkUpdateIfChanged( $defs{$n}, "ssh-id_rsa.pub",
        `cat ./.ssh/id_rsa.pub` );
    readingsBulkUpdateIfChanged( $defs{$n}, "container.hostname",
        `cat /etc/hostname` );
    readingsBulkUpdateIfChanged( $defs{$n}, "container.cap.e",
        `cat /docker.cap.e` );
    readingsBulkUpdateIfChanged( $defs{$n}, "container.cap.p",
        `cat /docker.cap.p` );
    readingsBulkUpdateIfChanged( $defs{$n}, "container.cap.i",
        `cat /docker.cap.i` );
    readingsBulkUpdateIfChanged( $defs{$n}, "container.id",
        `cat /docker.container.id` );
    readingsBulkUpdateIfChanged( $defs{$n}, "container.privileged",
        `cat /docker.privileged` );

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
