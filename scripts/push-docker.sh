#!/bin/bash
set -e

cd "$(readlink -f "$(dirname "$BASH_SOURCE")")"/..

if [ "${TRAVIS_PULL_REQUEST}" != "false" ]; then
  echo -e "\n\nThis build is related to pull request ${TRAVIS_PULL_REQUEST} and will not be published to Docker Hub."
  exit 0
fi

echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin

RETURN=0
for ID in $( docker images | grep '^fhem/*' | grep -v "<none>" | awk '{print $1":"$2}' | uniq ); do
  echo "Pushing ${ID} to Docker Hub registry ..."
  docker push "${ID}"
  RET=$?
  [ "${RET}" != 0 ] && RETURN=${RET}
done

if [ -s ./failed_variants ]; then
  echo -e "\n\nThe following variants failed integration test and where not published:"
  cat ./failed_variants
  exit 1
fi

exit ${RETURN}
