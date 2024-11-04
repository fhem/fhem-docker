## Migration vom V3 to V4 version of the docker image


Here are most common scenarios described, which needs migration.
May you have a very special setup which is not covered here. If so, feel free to open a issue.


### General

Installing packages in a running container isn't supported anymore, because this is a antipattern towards docker.
If you are an expert, you can still do this on your own, but here are only standard docker procedures explained:


You specified a custom Perl package via one of the environment variables xxxx_PKGS.


There a multiple options available to overcome this.
The ranked options are:

1. Open a issue, which package is missing.
If this requirement comes from a 3rdparty repository available at github, there is a way to add this to future versions of the image.
2. Modify your [docker-comppose.yaml](https://github.com/fhem/fhem-docker/blob/docs-v4/docker-compose.yml#L117):
   Extend the FHEM image via a build in your compose file. 
   Other options to archive this can be found in the docker documentation.
   You can extend the minimal or the full image.
   The example extends the full image:

  Remove the line with the image:
         
        image: ghcr.io/fhem/fhem-docker:4-bullseye


And add these lines to build a new image which your custom extension in your compose file:


      fhem:
        build:
          context: .
          dockerfile_inline: |
             FROM ghcr.io/fhem/fhem-docker:dev-bullseye 
             RUN <<EOF
             # Here you can add your custom build commands, installing every software you want
             EOF
        pull_policy: build



### Custom Perl package needed

You specified a custom Perl package via the environment variable:
   
     environment:
        - CPAN_PKGS="App::Name1 App::Name2"


Insert this line your compose file right under # Here you can add your custom build commands, installing every software you want

        cpm install --show-build-log-on-failure --configure-timeout=360 --workers=$(nproc) --local-lib-contained /usr/src/app/3rdparty/  << YOUR PAACKAGE NAME >>



### Custom Linux package needed

You specified a custom Perl package via the environment variable:

     environment:
        -e APT_PKGS="package1 package2"
    
Insert this lines to your compose file right under # Here you can add your custom build commands, installing every software you want

          LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get update 
          LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends << DEBIAN PACKAGENAME >>
          LC_ALL=C apt-get autoremove -qqy && LC_ALL=C apt-get clean 

###  Additional Python Packages needed

You specified a custom Perl package via the environment variable:

     environment:
        -e PIP_PKGS="package1 package2"

      Insert this line to your compose file right under # Here you can add your custom build commands, installing every software you want

         pip3 install --no-cache-dir <PIP PACKAGENAME>


###  Additional NodeJS Packages needed

        -e NPM_PKGS="package1 package2"


      Insert this lines to your compose file right under # Here you can add your custom build commands, installing every software you want

        npm install -g --unsafe-perm --production <NPM PACKAGENAME> 
        npm cache clean --force
