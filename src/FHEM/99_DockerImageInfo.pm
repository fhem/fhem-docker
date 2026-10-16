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

    # 99_ modules are always loaded by FHEM, even without a definition (fhem.cfg or configDB).
    # Create the definition after startup if it is missing, it is required by the health check.
    RemoveInternalTimer( q[DockerImageInfo_AutoDefine] );    # avoid multiple timers on reload
    InternalTimer( gettimeofday() + 1, \&DockerImageInfo_AutoDefine, q[DockerImageInfo_AutoDefine] );

    return FHEM::Meta::InitMod( __FILE__, $hash );
}

sub DockerImageInfo_AutoDefine {
    if ( !$init_done ) {
        InternalTimer( gettimeofday() + 1, \&DockerImageInfo_AutoDefine, q[DockerImageInfo_AutoDefine] );
        return;
    }

    return if ( defined( $modules{DockerImageInfo}{defptr} ) );
    return if ( !DockerImageInfo_IsContainerized() );
    return if ( ( $ENV{DOCKER_IMAGEINFO_AUTODEFINE} // q[1] ) eq q[0] );

    Log3 undef, 3, q[DockerImageInfo: no definition found, creating DockerImageInfo (run save to keep it, disable with DOCKER_IMAGEINFO_AUTODEFINE=0)];
    my $ret = CommandDefine( undef, q[DockerImageInfo DockerImageInfo] );
    Log3 undef, 1, qq[DockerImageInfo: automatic definition failed: $ret] if ( $ret );

    return undef;
}

sub DockerImageInfo_ReadFirstLine {
    my ($path) = @_;

    return q[] if ( !defined($path) || !-r $path );

    my $fileHdl;
    return q[] if ( !open( $fileHdl, q[<], $path ) );

    my $line = <$fileHdl>;
    close($fileHdl);

    return q[] if ( !defined($line) );
    chomp($line);

    return $line;
}

sub DockerImageInfo_IsContainerized {
    my $containerized = DockerImageInfo_ReadFirstLine(q[/containerized]);
    my $runtime       = DockerImageInfo_ReadFirstLine(q[/container.runtime]);

    return 1 if ( $containerized eq q[1] );
    return 1 if ( $runtime =~ m/^(?:kubernetes|docker|containerd|cri-o|podman|container)$/x );
    return 1 if ( -e q[/.dockerenv] );

    return 0;
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
        $attr{$name}{group} = 'System';
        $attr{$name}{icon}  = 'docker';
        $attr{$name}{room}  = 'System';
    }

    if ( DockerImageInfo_IsContainerized() ) {
        unlink( $hash->{URL_FILE});
        $hash->{STATE} = "Initialized";
        DockerImageInfo_GetImageInfo( $hash);
    }
    else {
        $hash->{STATE} = q[ERROR: Host is not a container];
    }

    # INITIALIZED was already sent when defined at runtime, so create the url file now
    DockerImageInfo_UpdateHealthCheck( $hash ) if ( $init_done );

    return undef;
}


sub DockerImageInfo_Notify
{
  my ($hash,$dev) = @_;

  return if($dev->{NAME} ne q[global]);

  my $events = deviceEvents($dev,1);
  if( defined first { $events->[$_] =~ /^INITIALIZED|REREADCFG$/ || $events->[$_] =~ /^ATTR\s.*\s(?:HTTPS|webname|DockerHealthCheck)\s.+/ } 0..$#{$events} ) {
    # Update available infos
    DockerImageInfo_GetImageInfo( $hash);

    return DockerImageInfo_UpdateHealthCheck( $hash);
  }

  return undef;
}


# Write the FHEMWEB urls used by health-check.sh and (re)start the status timer
sub DockerImageInfo_UpdateHealthCheck
{
  my ($hash) = @_;

  RemoveInternalTimer($hash);    # Stop Timer because we start one  again

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
    my %imageInfo;
    my @LINES = split( "\n", `sort -k1,1 -t'=' --stable --unique /image_info.* /image_info` );

    foreach my $LINE (@LINES) {
        next unless ( $LINE =~ /^org\.opencontainers\..+=.+$/i );
        my @NV = split( "=", $LINE );
        $NAME = shift @NV;
        $NAME =~ s/^org\.opencontainers\.//i;
        $VAL = join( "=", @NV );
        next if ( $NAME eq "image.authors" );
        $imageInfo{$NAME} = $VAL;
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

    my $runtime = DockerImageInfo_ReadFirstLine(q[/container.runtime]);
    $runtime = ( -e q[/.dockerenv] ) ? q[docker] : q[host] if ( $runtime eq q[] );

    my $containerized = DockerImageInfo_ReadFirstLine(q[/containerized]);
    $containerized = DockerImageInfo_IsContainerized() ? q[1] : q[0] if ( $containerized eq q[] );

    readingsBulkUpdateIfChanged( $hash, q[ssh-id_ed25519.pub],    DockerImageInfo_ReadFirstLine(q[./.ssh/id_ed25519.pub]) );
    readingsBulkUpdateIfChanged( $hash, q[ssh-id_rsa.pub],        DockerImageInfo_ReadFirstLine(q[./.ssh/id_rsa.pub]) );
    readingsBulkUpdateIfChanged( $hash, q[container.hostname],    DockerImageInfo_ReadFirstLine(q[/etc/hostname]) );
    readingsBulkUpdateIfChanged( $hash, q[container.runtime],     $runtime );
    readingsBulkUpdateIfChanged( $hash, q[containerized],         $containerized );
    readingsBulkUpdateIfChanged( $hash, q[container.cap.e],       DockerImageInfo_ReadFirstLine(q[/docker.container.cap.e]) );
    readingsBulkUpdateIfChanged( $hash, q[container.cap.p],       DockerImageInfo_ReadFirstLine(q[/docker.container.cap.p]) );
    readingsBulkUpdateIfChanged( $hash, q[container.cap.i],       DockerImageInfo_ReadFirstLine(q[/docker.container.cap.i]) );
    readingsBulkUpdateIfChanged( $hash, q[container.id],          DockerImageInfo_ReadFirstLine(q[/docker.container.id]) );
    readingsBulkUpdateIfChanged( $hash, q[container.privileged],  DockerImageInfo_ReadFirstLine(q[/docker.privileged]) );
    readingsBulkUpdateIfChanged( $hash, q[container.hostnetwork], DockerImageInfo_ReadFirstLine(q[/docker.hostnetwork]) );

    my @modelParts = ( qq[runtime=$runtime] );
    for my $label (qw(image.title image.version image.source)) {
        push( @modelParts, qq[$label=$imageInfo{$label}] ) if ( defined( $imageInfo{$label} ) && $imageInfo{$label} ne q[] );
    }
    readingsBulkUpdateIfChanged( $hash, q[model], join( q[; ], @modelParts ) );

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
    <br><br>

    The reading <code>model</code> summarizes the detected runtime and image metadata,
    for example <code>runtime=kubernetes; image.version=5-bookworm</code>. The revision
    (git commit) of the image is available separately as the <code>image.revision</code>
    reading and is intentionally excluded from <code>model</code>, so that <code>model</code>
    stays stable across builds of the same image version.
    The reading <code>container.runtime</code> contains <code>kubernetes</code>,
    <code>docker</code>, <code>containerd</code>, <code>cri-o</code>, <code>podman</code> or <code>host</code>.
    <br><br>

    The definition is required by the health check of the container. Without it the health
    check fails (Docker marks the container unhealthy, Kubernetes restarts it).
    Shortly after FHEM has started, the module creates <code>DockerImageInfo</code> automatically,
    but only if no definition of this type exists yet (its name does not matter), e.g. with a
    migrated <code>fhem.cfg</code> or with <code>configDB</code>.
    <ul>
      <li>The module does not save the definition itself. FHEMWEB then shows unsaved changes;
          run <code>save</code> once to keep the definition in your configuration (with
          <code>configDB</code> it is stored in the database). Afterwards nothing is created
          automatically anymore.</li>
      <li>Any later <code>save</code> stores the definition, including the automatic save of
          <code>autosave</code>.</li>
      <li>A definition deleted on purpose is created again on the next start. Set the container
          environment variable <code>DOCKER_IMAGEINFO_AUTODEFINE=0</code> to disable the
          automatic definition.</li>
      <li>After <code>rereadcfg</code> with a configuration without this definition, it is only
          created again on the next restart of FHEM.</li>
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
    <br><br>

    Das Reading <code>model</code> fasst die erkannte Runtime und Image-Metadaten zusammen,
    zum Beispiel <code>runtime=kubernetes; image.version=5-bookworm</code>. Die Revision
    (Git-Commit) des Images steht separat als Reading <code>image.revision</code> zur
    Verfügung und wird bewusst nicht in <code>model</code> aufgenommen, damit
    <code>model</code> über Builds derselben Image-Version hinweg stabil bleibt.
    Das Reading <code>container.runtime</code> enth&auml;lt <code>kubernetes</code>,
    <code>docker</code>, <code>containerd</code>, <code>cri-o</code>, <code>podman</code> oder <code>host</code>.
    <br><br>

    Die Definition wird f&uuml;r den Healthcheck des Containers ben&ouml;tigt. Ohne sie schl&auml;gt
    der Healthcheck fehl (Docker meldet den Container als unhealthy, Kubernetes startet ihn neu).
    Kurz nach dem Start von FHEM legt das Modul <code>DockerImageInfo</code> automatisch an,
    aber nur, wenn noch keine Definition dieses Typs existiert (der Name spielt keine Rolle),
    z. B. bei mitgebrachter <code>fhem.cfg</code> oder bei <code>configDB</code>.
    <ul>
      <li>Das Modul speichert die Definition nicht selbst. FHEMWEB zeigt danach ungespeicherte
          &Auml;nderungen an; einmal <code>save</code> ausf&uuml;hren, um die Definition in die
          Konfiguration zu &uuml;bernehmen (bei <code>configDB</code> landet sie in der Datenbank).
          Danach wird nichts mehr automatisch angelegt.</li>
      <li>Jedes sp&auml;tere <code>save</code> speichert die Definition mit, auch das automatische
          Speichern durch <code>autosave</code>.</li>
      <li>Eine bewusst gel&ouml;schte Definition wird beim n&auml;chsten Start erneut angelegt. Mit der
          Umgebungsvariable <code>DOCKER_IMAGEINFO_AUTODEFINE=0</code> des Containers l&auml;sst sich
          die automatische Anlage abschalten.</li>
      <li>Nach <code>rereadcfg</code> mit einer Konfiguration ohne diese Definition wird sie erst beim
          n&auml;chsten Neustart von FHEM wieder angelegt.</li>
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
