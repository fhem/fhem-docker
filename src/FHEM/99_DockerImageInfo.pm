package main;

use strict;
use warnings;
use FHEM::Meta;
use List::Util qw( first );

sub DockerImageInfo_Initialize {
    my ($hash) = @_;

    $hash->{NOTIFYDEV} = q[global]; # limit calls to notify
    $hash->{DefFn}     = \&DockerImageInfo_Define;
    $hash->{NotifyFn}  = \&DockerImageInfo_Notify;
    $hash->{UndefFn}   = \&DockerImageInfo_Undefine;
    $hash->{AttrList}  = $readingFnAttributes;

    return FHEM::Meta::InitMod( __FILE__, $hash );
}

###################################
sub DockerImageInfo_Define {
    my ( $hash, $def ) = @_;
    my @a    = split( "[ \t][ \t]*", $def );
    my $name = $hash->{NAME};

    return q[Wrong syntax: use define <name> DockerImageInfo]
      if ( int(@a) != 2 );

    return q[This module may only be defined once, existing device: ]. $modules{ $hash->{TYPE} }{defptr}{NAME}
      if ( defined( $modules{ $hash->{TYPE} }{defptr} )
        && $init_done
        && !defined( $hash->{OLDDEF} ) );

    # Initialize the module and the device
    return $@ unless ( FHEM::Meta::SetInternals($hash) );

    # create global unique device definition
    $modules{ $hash->{TYPE} }{defptr} = $hash;

    $hash->{INFO_DIR} = q[/tmp]; 
    #$hash->{INFO_DIR} = "/fhem-docker/var"; # TODO: Clean up dumping all files in the container root
    $hash->{URL_FILE} = qq[$hash->{INFO_DIR}/health-check.urls];
    $hash->{RESULT_FILE} = qq[$hash->{INFO_DIR}/health-check.result];

    if ( $init_done && !defined( $hash->{OLDDEF} ) ) {

        # presets for FHEMWEB
        $attr{$name}{alias} = 'Docker Image Info';
        $attr{$name}{devStateIcon} = q[^ok.*:security@green Initialized:system_fhem_reboot@orange .*:message_attention@red];
        $attr{$name}{group} = 'Update';
        $attr{$name}{icon}  = 'docker';
        $attr{$name}{room}  = 'System';
    }

    if ( -e '/.dockerenv' ) {
        unlink( $hash->{URL_FILE});
        $hash->{STATE} = "Initialized";
        DockerImageInfo_GetImageInfo( $hash);
    }
    else {
        $hash->{STATE} = q[ERROR: Host is not a container];
    }

    return undef;
}


sub DockerImageInfo_Notify
{
  my ($hash,$dev) = @_;

  return if($dev->{NAME} ne q[global]);

  my $events = deviceEvents($dev,1);
  if( defined first { $events->[$_] =~ /^INITIALIZED|REREADCFG$/ || $events->[$_] =~ /^ATTR\s.*\s(?:HTTPS|webname|DockerHealthCheck)\s.+/ } 0..$#{$events} ) {
    RemoveInternalTimer($hash);    # Stop Timer because we start one  again
    
    # Update available infos
    DockerImageInfo_GetImageInfo( $hash);


    foreach ( devspec2array(q[TYPE=FHEMWEB:FILTER=TEMPORARY!=1]) ) {
      # add userattr to FHEMWEB devices to control healthcheck
      addToDevAttrList( $_, q[DockerHealthCheck:0,1] );
    }  

    my $urlFile = $hash->{URL_FILE};
    my $urlFileHdl;
    if(!open($urlFileHdl, ">$urlFile")) {
      my $msg = q[WriteStatefile: Cannot open $urlFile: $!];
      Log3 $hash->{NAME}, 1, $msg;
      return $msg;
    }
    binmode($urlFileHdl, ':encoding(UTF-8)') if($unicodeEncoding);
    foreach ( devspec2array(q[TYPE=FHEMWEB:FILTER=TEMPORARY!=1:FILTER=DockerHealthCheck!=0]) ) {
      # build url and write it to healthcheck file
      my $webHash   = $defs{$_};
      my $port      = $webHash->{PORT};
      my $webname   = AttrVal( $_, 'webname', 'fhem');
      my $https     = AttrVal( $_, 'HTTPS', '0');
      my $proto     = ($https) ? 'https' : 'http';
      print $urlFileHdl qq[$proto://localhost:$port/$webname/healthcheck\n];
    }
    close($urlFileHdl);

    InternalTimer(gettimeofday()+30, \&DockerImageInfo_GetStatus, $hash);
  }

  return undef;
}


sub DockerImageInfo_Undefine {
    my ( $hash, $def ) = @_;
    unlink( $hash->{URL_FILE});
    delete $modules{'DockerImageInfo'}{defptr};
}


sub DockerImageInfo_GetStatus {
  my ( $hash ) = @_;

  InternalTimer(gettimeofday()+30, \&DockerImageInfo_GetStatus, $hash);

  my $resultFile = $hash->{RESULT_FILE};
  my $resultFileHdl;
  if(!open($resultFileHdl, "<$resultFile")) {
    my $msg = qq[Read result file: Cannot open $resultFile: $!];
    Log3 $hash->{NAME}, 1, $msg;
    $hash->{STATE} = $msg;
    return undef;
  }
  $hash->{STATE} = do { local $/; <$resultFileHdl> };
  close( $resultFileHdl);

  return undef;
}


sub DockerImageInfo_GetImageInfo {
    my ($hash) = @_;

    readingsBeginUpdate( $hash );

    my $NAME;
    my $VAL;
    my @LINES = split( "\n", `sort -k1,1 -t'=' --stable --unique /image_info.* /image_info` );

    foreach my $LINE (@LINES) {
        next unless ( $LINE =~ /^org\.opencontainers\..+=.+$/i );
        my @NV = split( "=", $LINE );
        $NAME = shift @NV;
        $NAME =~ s/^org\.opencontainers\.//i;
        $VAL = join( "=", @NV );
        next if ( $NAME eq "image.authors" );
        readingsBulkUpdateIfChanged( $hash, $NAME, $VAL );
    }

    $VAL   = '[ ';
    @LINES = split( "\n", `sort --stable --unique /etc/sudoers.d/fhem*` );
    foreach my $LINE (@LINES) {
        $VAL .= ', ' unless ( $VAL eq '[ ' );
        $LINE =~ s/"/\\"/g;
        $VAL .= "\"$LINE\"";
    }
    $VAL .= ' ]';
    readingsBulkUpdateIfChanged( $hash, 'sudoers', $VAL );

    my $ID = `id`;
    if ( $ID =~ m/^uid=(\d+)\((\w+)\)\s+gid=(\d+)\((\w+)\)\s+groups=((?:\d+\(\w+\),)*(?:\d+\(\w+\)))$/i  )
    {
        readingsBulkUpdateIfChanged( $hash, 'id.uid',   $1 );
        readingsBulkUpdateIfChanged( $hash, 'id.uname', $2 );
        readingsBulkUpdateIfChanged( $hash, 'id.gid',   $3 );
        readingsBulkUpdateIfChanged( $hash, 'id.gname', $4 );

        $VAL = '[ ';
        foreach my $group ( split( ',', $5 ) ) {
            if ( $group =~ m/^(\d+)\((\w+)\)$/ ) {
                $VAL .= ', ' unless ( $VAL eq '[ ' );
                $VAL .= "\"$2\": $1";
            }
        }
        $VAL .= ' ]';

        readingsBulkUpdateIfChanged( $hash, 'id.groups', $VAL );
    }

    readingsBulkUpdateIfChanged( $hash, q[ssh-id_ed25519.pub],    `cat ./.ssh/id_ed25519.pub` );
    readingsBulkUpdateIfChanged( $hash, q[ssh-id_rsa.pub],        `cat ./.ssh/id_rsa.pub` );
    readingsBulkUpdateIfChanged( $hash, q[container.hostname],    `cat /etc/hostname` );
    readingsBulkUpdateIfChanged( $hash, q[container.cap.e],       `cat /docker.container.cap.e` );
    readingsBulkUpdateIfChanged( $hash, q[container.cap.p],       `cat /docker.container.cap.p` );
    readingsBulkUpdateIfChanged( $hash, q[container.cap.i],       `cat /docker.container.cap.i` );
    readingsBulkUpdateIfChanged( $hash, q[container.id],          `cat /docker.container.id` );
    readingsBulkUpdateIfChanged( $hash, q[container.privileged],  `cat /docker.privileged` );
    readingsBulkUpdateIfChanged( $hash, q[container.hostnetwork], `cat /docker.hostnetwork` );

    readingsEndUpdate( $hash, 1 );
}

1;

=pod
=encoding utf8
=item helper
=item summary Kommunikationsmodul zwischen Docker Umgebung und FHEM
=item summary_DE Commumnication between docker environment and FHEM

=begin html

<a name="DockerImageInfo"></a>
<h3>DockerImageInfo</h3>
<ul>

  Show infos about the Docker image FHEM is running in and allows the configuration of the WEB definitions used for healthcheck.
  Only works together with the fhem-docker image from  https://github.com/fhem/fhem-docker/ .
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

  <a name="DockerImageInfoattr"></a>
  <b>attr</b>
  <ul>
      <code>attr &lt;name&gt; &lt;attribute&gt; &lt;value&gt;</code>
      <br><br>
      See <a href="http://fhem.de/commandref.html#attr">commandref#attr</a> for more info about 
      the attr command.
      <br><br>
      Attributes:
      <ul>
          <li><i>DockerHealthCheck</i> 0|1<br>
              Attribute is available in all definitions of type WEB.
              Default is, every definition is used for the healthcheck. 
              The behaviuor can be diabled with this attribute.
          </li>
      </ul>
  </ul>

</ul>

=end html

=begin html_DE

<a name="DockerImageInfo"></a>
<h3>DockerImageInfo</h3>
<ul>

  Zeigt Informationen &uuml;ber das Docker Image, in dem FHEM gerade l&auml;ft und ermöglicht die Konfiguration der WEB Definitionen für den Healthcheck
  Funktioniert mit dem fhem-docker image von https://github.com/fhem/fhem-docker .
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

  <a name="DockerImageInfoattr"></a>
  <b>attr</b>
  <ul>
      <code>attr &lt;name&gt; &lt;attribute&gt; &lt;value&gt;</code>
      <br><br>
      See <a href="http://fhem.de/commandref.html#attr">commandref#attr</a> für mehr Information zum attr Kommando.
      <br><br>
      Attributes:
      <ul>
          <li><i>DockerHealthCheck</i> 0|1<br>
              Das Attribute wird in allen Definition des Typs WEB bereitgestellt.
              Der Standardwert ist, dass jede WEB Definition für den Healthcheck verwendet wird.
              Mit diesem Attribut, kann der Healthcheck auf eine Webdefinition deaktiviert werden.
          </li>
      </ul>
  </ul>

  <br>

</ul>

=end html_DE

=for :application/json;q=META.json 99_DockerImageInfo.pm
{
  "version": "v1.0.0",
  "x_release_date": "2023-11-09",
  "name": "99_DockerImageInfo.pm",
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
    "sidey79"
  ],
  "prereqs": {
    "runtime": {
      "requires": {
        "strict": 0,
        "warnings": 0,
        "FHEM::Meta": 0.001006,
        "List::Util" : 1.18
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
