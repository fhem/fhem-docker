# Legacy Images

`#legacy` `#eol` `#v4` `#v3` `#standard` `#minimal`

This page documents the old image generations that remain available for compatibility only. They are legacy and no longer the recommended choice for new setups.

## Standard image

### Version 4

`ghcr.io/fhem/fhem-docker:4-bullseye`  
`ghcr.io/fhem/fhem-docker:4-threaded-bullseye`

- Debian bullseye
- Perl 5.38.5, optional threaded variant
- NodeJS 18 LTS
- Python 3.9.2 and Python 2.7.18
- Supported platforms: `linux/amd64`, `linux/arm/v7`, `linux/arm64`
- Does not include `alexa-fhem`, `alexa-cookie`, `gassistant-fhem`, `homebridge`, `homebridge-fhem`, or `tradfri-fhem` by default
- Useful when you need additional preinstalled Perl modules for 3rd party modules
- Requires at least FHEM revision `25680`
- EOL: January 2025

### Version 3

`ghcr.io/fhem/fhem-docker:3-buster`

- Debian buster
- Perl 5.28.1
- NodeJS 16 LTS
- Python 3
- Supported platforms: `linux/amd64`, `linux/arm/v7`, `linux/arm64`
- Does not include `alexa-fhem`, `alexa-cookie`, `gassistant-fhem`, `homebridge`, `homebridge-fhem`, or `tradfri-fhem` by default
- EOL: January 2024

## Minimal image

### Version 4

`ghcr.io/fhem/fhem-minimal-docker:4-bullseye`  
`ghcr.io/fhem/fhem-minimal-docker:4-threaded-bullseye`

- Debian bullseye
- Perl 5.38.5, optional threaded variant
- Python 3.9.2 and Python 2.7.18
- Supported platforms: `linux/amd64`, `linux/arm/v7`, `linux/arm64`, `linux/i386`
- Best fit when you only use FHEM svn modules and install everything else yourself
- EOL: January 2025

### Version 3

`ghcr.io/fhem/fhem-minimal-docker:3-buster`

- Debian buster
- Perl 5.28.1
- Supported platforms: `linux/amd64`, `linux/arm/v7`, `linux/arm64`, `linux/i386`
- Best fit when you only use FHEM svn modules and install everything else yourself
- EOL: January 2024

## Deprecated package-installation variables

Image versions 3 and older supported installing packages during initial container setup through environment variables. This mode is deprecated. Prefer extending the image with Docker build steps instead.

```shell
-e APT_PKGS="package1 package2"
-e CPAN_PKGS="App::Name1 App::Name2"
-e PIP_PKGS="package1 package2"
-e NPM_PKGS="package1 package2"
```

## Notes

- Keep these tags pinned only for existing deployments.
- Prefer current 5.x images for new installs.
