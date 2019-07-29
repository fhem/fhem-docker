package main;

use strict;
use warnings;
use FHEM::Meta;

sub DockerImageInfo_Initialize($) {
    my ($hash) = @_;

    $hash->{DefFn}    = "DockerImageInfo_Define";
    $hash->{AttrList} = $readingFnAttributes;

    # add userattr to FHEMWEB devices to control healthcheck
    foreach (devspec2array("TYPE=FHEMWEB:FILTER=TEMPORARY!=1")) {
        addToDevAttrList( $_, 'DockerHealthCheck:1,0' );
    }

    return FHEM::Meta::InitMod( __FILE__, $hash );
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

    # Initialize the module and the device
    return $@ unless ( FHEM::Meta::SetInternals($hash) );

    # create global unique device definition
    $modules{ $hash->{TYPE} }{defptr} = $hash;

    if ( $init_done && !defined( $hash->{OLDDEF} ) ) {

        # presets for FHEMWEB
        $attr{$name}{alias} = 'Docker Image Info';
        $attr{$name}{devStateIcon} =
'ok:security@green Initialized:system_fhem_reboot@orange .*:message_attention@red';
        $attr{$name}{group} = 'Update';
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

    my $NAME;
    my $VAL;
    my @LINES = split( "\n",
        `sort -k1,1 -t'=' --stable --unique /image_info.* /image_info` );

    foreach my $LINE (@LINES) {
        next unless ( $LINE =~ /^org\.opencontainers\..+=.+$/i );
        my @NV = split( "=", $LINE );
        $NAME = shift @NV;
        $NAME =~ s/^org\.opencontainers\.//i;
        $VAL = join( "=", @NV );
        next if ( $NAME eq "image.authors" );
        readingsBulkUpdateIfChanged( $defs{$n}, $NAME, $VAL );
    }

    $VAL = '[ ';
    @LINES = split( "\n", `sort --stable --unique /etc/sudoers.d/fhem*` );
    foreach my $LINE (@LINES) {
        $VAL .= ', ' unless ( $VAL eq '[ ' );
        $LINE =~ s/"/\\"/g;
        $VAL .= "\"$LINE\"";
    }
    $VAL .= ' ]';
    readingsBulkUpdateIfChanged( $defs{$n}, 'sudoers', $VAL );

    my $ID = `id`;
    if ( $ID =~
m/^uid=(\d+)\((\w+)\)\s+gid=(\d+)\((\w+)\)\s+groups=((?:\d+\(\w+\),)*(?:\d+\(\w+\)))$/i
      )
    {
        readingsBulkUpdateIfChanged( $defs{$n}, 'id.uid',   $1 );
        readingsBulkUpdateIfChanged( $defs{$n}, 'id.uname', $2 );
        readingsBulkUpdateIfChanged( $defs{$n}, 'id.gid',   $3 );
        readingsBulkUpdateIfChanged( $defs{$n}, 'id.gname', $4 );

        $VAL = '[ ';
        foreach my $group ( split( ',', $5 ) ) {
            if ( $group =~ m/^(\d+)\((\w+)\)$/ ) {
                $VAL .= ', ' unless ( $VAL eq '[ ' );
                $VAL .= "\"$2\": $1";
            }
        }
        $VAL .= ' ]';

        readingsBulkUpdateIfChanged( $defs{$n}, 'id.groups', $VAL );
    }

    readingsBulkUpdateIfChanged( $defs{$n}, "ssh-id_ed25519.pub",
        `cat ./.ssh/id_ed25519.pub` );
    readingsBulkUpdateIfChanged( $defs{$n}, "ssh-id_rsa.pub",
        `cat ./.ssh/id_rsa.pub` );
    readingsBulkUpdateIfChanged( $defs{$n}, "container.hostname",
        `cat /etc/hostname` );
    readingsBulkUpdateIfChanged( $defs{$n}, "container.cap.e",
        `cat /docker.container.cap.e` );
    readingsBulkUpdateIfChanged( $defs{$n}, "container.cap.p",
        `cat /docker.container.cap.p` );
    readingsBulkUpdateIfChanged( $defs{$n}, "container.cap.i",
        `cat /docker.container.cap.i` );
    readingsBulkUpdateIfChanged( $defs{$n}, "container.id",
        `cat /docker.container.id` );
    readingsBulkUpdateIfChanged( $defs{$n}, "container.privileged",
        `cat /docker.privileged` );
    readingsBulkUpdateIfChanged( $defs{$n}, "container.hostnetwork",
        `cat /docker.hostnetwork` );

    readingsEndUpdate( $defs{$n}, 1 );
    return undef;
}

1;

=pod
=encoding utf8
=item helper
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

=for :application/json;q=META.json 99_DockerImageInfo.pm
{
  "version": "v0.6.0",
  "x_release_date": "2019-07-28",
  "release_status": "stable",
  "license": [
    "MIT"
  ],
  "abstract": "Shows information about the FHEM Docker Image in use and the running container",
  "description": "This is a companion FHEM module and built-in to the official FHEM Docker Image on <a href=\"https://hub.docker.com/r/fhem/fhem\" target=\"_blank\">Docker Hub</a>.",
  "x_lang": {
  "de": {
    "abstract": "Zeigt Informationen über das aktuell verwendete FHEM Docker Image und den laufenden Container",
    "description": "Dies ist ein begeleitendes FHEM Modul und fest im FHEM Docker Image <a href=\"https://hub.docker.com/r/fhem/fhem\" target=\"_blank\">Docker Hub</a> eingebaut."
    }
  },
  "author": [
    "Julian Pawlowski <julian.pawlowski@gmail.com>"
  ],
  "x_fhem_maintainer": [
    "loredo"
  ],
  "x_fhem_maintainer_github": [
    "jpawlowski"
  ],
  "prereqs": {
    "runtime": {
      "requires": {
        "strict": 0,
        "warnings": 0,
        "FHEM::Meta": 0.001006
      },
      "recommends": {
      },
      "suggests": {
      }
    }
  },
  "resources": {
    "license": [
      "https://github.com/fhem/fhem-docker/blob/master/LICENSE"
    ],
    "homepage": "https://github.com/fhem/fhem-docker/",
    "x_support_community" : {
      "board" : "Server - Linux",
      "boardId" : 33,
      "cat" : "FHEM - Hardware",
      "description" : "FHEM auf Linux Servern",
      "forum" : "FHEM Forum",
      "language" : "de",
      "rss" : "https://forum.fhem.de/index.php?action=.xml;type=rss;board=33",
      "title" : "FHEM Forum: Server - Linux",
      "web" : "https://forum.fhem.de/index.php/board,33.0.html"
    },
    "bugtracker": {
      "web": "https://github.com/fhem/fhem-docker/issues",
      "x_web_title": "Github Issues for fhem/fhem-docker"
    },
    "repository": {
      "type": "git",
      "url": "https://github.com/fhem/fhem-docker.git",
      "web": "https://github.com/fhem/fhem-docker/blob/master/src/99_DockerImageInfo.pm",
      "x_branch": "master",
      "x_filepath": "src/",
      "x_raw": "https://github.com/fhem/fhem-docker/raw/master/src/99_DockerImageInfo.pm",
      "x_dev": {
        "type": "git",
        "url": "https://github.com/fhem/fhem-docker.git",
        "web": "https://github.com/fhem/fhem-docker/blob/dev/src/99_DockerImageInfo.pm",
        "x_branch": "dev",
        "x_filepath": "src/",
        "x_raw": "https://github.com/fhem/fhem-docker/raw/dev/src/99_DockerImageInfo.pm"
      }
    }
  }
}
=end :application/json;q=META.json

=cut
