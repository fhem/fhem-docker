## Migration vom V3 to V4 version of the docker image


Here are most common szenarios described, which needs migration.
May you have a very special setup which is not covered here. If so, feel free to open a issue.


### Custom Perl package needed

You specified a custom perl packge via the enviornment variabe:
   
     environment:
        - CPAN_PKGS="App::Name1 App::Name2"

There a serval options available to overcome this.
The ranked options are:

1. Open a issue, which package is missing.
If this requirement comes from a 3rdparty repository available at github, there is a way to add this to future versions of the image.
2. Modify your [docker-comppose.yaml](https://github.com/fhem/fhem-docker/blob/docs-v4/docker-compose.yml#L117):
   Extend the fhem image via a build in your compose file. 
   Other otions to archive this can be found in the docker documatation.
   You can extend the minimal or the full image.
   The example extends the full image:

  Remove the line with the image:
         
        image: ghcr.io/fhem/fhem-docker:4-bullseye

  And add these lines to build a new image which your custom extension:
  
      fhem:
        build:
          context: .
          dockerfile_inline: |
             FROM ghcr.io/fhem/fhem-docker:dev-bullseye 
             RUN <<EOF
               cpm install --show-build-log-on-failure --configure-timeout=360 --workers=$(nproc) --local-lib-contained /usr/src/app/3rdparty/ Eixo::Docker
             EOF
        pull_policy: build

