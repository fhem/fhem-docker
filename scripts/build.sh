#!/bin/bash
set -e
echo "Building for platform: `uname -a`"
TRAVIS_BRANCH=${TRAVIS_BRANCH:-`git branch | sed -n -e 's/^\* \(.*\)/\1/p'`}
LABEL=${LABEL:-`uname -m`_linux}
echo "TRAVIS_BRANCH = ${TRAVIS_BRANCH}"
echo "TRAVIS_TAG = ${TRAVIS_TAG}"
[[ -n "${TRAVIS_BRANCH}" && "${TRAVIS_BRANCH}" != "master" ]] && set -x

cd "$(readlink -f "$(dirname "${BASH_SOURCE}")")"/..

BUILD_DATE=$( date --iso-8601=seconds --utc )
BASE="fhem/fhem-${LABEL}"
BASE_IMAGE="debian"
BASE_IMAGE_TAG="buster"

# Download dependencies if not existing
if [ ! -d ./src/fhem ]; then
  svn co https://svn.fhem.de/fhem/trunk ./src/fhem/trunk;
fi
if [ ! -s ~/.docker/cli-plugins/docker-buildx ]; then
 echo "Try Installing buildx"
 export DOCKER_BUILDKIT=1
 docker build --platform=local -o . git://github.com/docker/buildx
 mkdir -p ~/.docker/cli-plugins
 mv buildx ~/.docker/cli-plugins/docker-buildx
fi 


FHEM_VERSION="$( svn ls "^/tags" https://svn.fhem.de/fhem/ | grep "FHEM_" | sort | tail -n 1 | cut -d / -f 1 | cut -d " " -f 1 |cut -d _ -f 2- | sed s/_/./g )"
FHEM_REVISION_LATEST="$( cd ./src/fhem/trunk; svn info -r HEAD | grep "Revision" | cut -d " " -f 2 )"

if [[ -n "${ARCH}" && "${ARCH}" != "amd64" ]]; then
  BASE_IMAGE="${ARCH}/${BASE_IMAGE}"
  if [ "${ARCH}" != "i386" ]; then
    echo "Starting QEMU environment for multi-arch build ..."
    docker run --rm --privileged --name qemu multiarch/qemu-user-static:register --reset
  fi
fi

IMAGE_VERSION=$(git describe --tags --dirty --match "v[0-9]*")
IMAGE_VERSION=${IMAGE_VERSION:-1}

if [[ -z "${FHEM_VERSION}" || -z "${FHEM_REVISION_LATEST}" || -z "${IMAGE_VERSION}" ]]; then
  echo "ERROR: Unable to collect all required version info:"
  echo " FHEM_VERSION=${FHEM_VERSION}"
  echo " FHEM_REVISION_LATEST=${FHEM_REVISION_LATEST}"
  echo " IMAGE_VERSION=${IMAGE_VERSION}"
  exit 1
fi

IMAGE_BRANCH=$( [[ -n "${TRAVIS_BRANCH}" && "${TRAVIS_BRANCH}" != "master" && "${TRAVIS_BRANCH}" != "${TRAVIS_TAG}" ]] && echo -n "${TRAVIS_BRANCH}" || echo -n "" )
VARIANT_FHEM="${FHEM_VERSION}-s${FHEM_REVISION_LATEST}"
VARIANT_IMAGE="${IMAGE_VERSION}$( [ -n "${IMAGE_BRANCH}" ] && echo -n "-${IMAGE_BRANCH}" || echo -n "" )"
VARIANT="${VARIANT_FHEM}_${VARIANT_IMAGE}"

echo -e "\n\nNow building variant ${VARIANT} ...\n\n"

# Only run build if not existing on Docker hub yet
function docker_tag_exists() {
  if [[ "x${DOCKER_USER}" == "x" || "x${DOCKER_PASS}" == "x" ]]; then
    return 1
  fi
  set +x
  TOKEN=$(curl -fs -H "Content-Type: application/json" -X POST -d '{"username": "'${DOCKER_USER}'", "password": "'${DOCKER_PASS}'"}' https://hub.docker.com/v2/users/login/ | jq -r .token)
  EXISTS=$(curl -fs -H "Authorization: JWT ${TOKEN}" https://hub.docker.com/v2/repositories/$1/tags/?page_size=10000 | jq -r "[.results | .[] | .name == \"$2\"] | any")
  [[ -n "${TRAVIS_BRANCH}" && "${TRAVIS_BRANCH}" != "master" ]] && set -x
  test $EXISTS = true
}
if docker_tag_exists ${BASE} ${VARIANT}; then
  echo "Variant ${VARIANT} already existig on Docker Hub - skipping build."
  continue
fi

# Detect rolling tag for this build
if [[ -z "${TRAVIS_BRANCH}" || "${TRAVIS_BRANCH}" == "master" || "${TRAVIS_BRANCH}" == "${TRAVIS_TAG}" ]]; then
      TAG="latest"
else
  TAG="${TRAVIS_BRANCH}"
fi

# Check for image availability on Docker hub registry
if docker_tag_exists ${BASE} ${TAG}; then
  echo "Found prior build ${BASE}:${TAG} on Docker Hub registry"
  CACHE_TAG=${TAG}
  docker pull "${BASE}:${CACHE_TAG}"
else
  echo "No prior build found for ${BASE}:${TAG} on Docker Hub registry"
fi

docker buildx build \
  $( [ -n "${CACHE_TAG}" ] && echo -n "--cache-from "${BASE}:${CACHE_TAG}"" ) \
  --tag "${BASE}:${VARIANT}" \
  --build-arg BASE_IMAGE=${BASE_IMAGE} \
  --build-arg BASE_IMAGE_TAG=${BASE_IMAGE_TAG} \
  --build-arg ARCH=${ARCH} \
  --build-arg PLATFORM="linux" \
  --build-arg BUILD_DATE=${BUILD_DATE} \
  --build-arg TAG=${VARIANT} \
  --build-arg TAG_ROLLING=${TAG} \
  --build-arg IMAGE_VERSION=${VARIANT} \
  --build-arg IMAGE_VCS_REF=${TRAVIS_COMMIT} \
  --build-arg FHEM_VERSION=${VARIANT_FHEM} \
  --build-arg VCS_REF=${FHEM_REVISION_LATEST} \
  --platform linux/amd64 \
  .

# Add rolling tag to this build
[ -n "${TAG}" ] && docker tag "${BASE}:${VARIANT}" "${BASE}:${TAG}"

exit 0
