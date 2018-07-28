#!/bin/bash
set -e

if [ "${TRAVIS_PULL_REQUEST}" != "false" ]; then
  exit 0
fi

echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
sleep $[ ( $RANDOM % 10 )  + 1 ]s

for VARIANT in $( docker images | grep '^fhem/*' | grep -v "<none>" | grep -P ' dev|beta|latest ' | awk '{print $2}' | uniq | sort ); do
  echo "Creating manifest file fhem/fhem:${VARIANT} ..."
  docker manifest create fhem/fhem:${VARIANT} \
    fhem/fhem-amd64_linux:${VARIANT} \
    fhem/fhem-i386_linux:${VARIANT} \
    fhem/fhem-arm32v5_linux:${VARIANT} \
    fhem/fhem-arm32v7_linux:${VARIANT} \
    fhem/fhem-arm64v8_linux:${VARIANT}
  docker manifest annotate fhem/fhem:${VARIANT} fhem/fhem-arm32v5_linux:${VARIANT} --os linux --arch arm --variant v5
  docker manifest annotate fhem/fhem:${VARIANT} fhem/fhem-arm32v7_linux:${VARIANT} --os linux --arch arm --variant v7
  docker manifest annotate fhem/fhem:${VARIANT} fhem/fhem-arm64v8_linux:${VARIANT} --os linux --arch arm64 --variant v8
  docker manifest inspect fhem/fhem:${VARIANT}

  echo "Pushing manifest fhem/fhem:${VARIANT} to Docker Hub ..."
  docker manifest push fhem/fhem:${VARIANT}

  echo "Requesting current manifest from Docker Hub ..."
  docker run --rm mplatform/mquery fhem/fhem:${VARIANT}
done

exit 0
