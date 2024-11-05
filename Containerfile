## 1. BUILD ARGS
# These allow changing the produced image by passing different build args to adjust
# the source from which your image is built.
# Build args can be provided on the commandline when building locally with:
#   podman build -f Containerfile --build-arg FEDORA_VERSION=40 -t local-image

# SOURCE_IMAGE arg can be anything from ublue upstream which matches your desired version:
# See list here: https://github.com/orgs/ublue-os/packages?repo_name=main
# - "silverblue"
# - "kinoite"
# - "sericea"
# - "onyx"
# - "lazurite"
# - "vauxite"
# - "base"
#
#  "aurora", "bazzite", "bluefin" or "ucore" may also be used but have different suffixes.
ARG SOURCE_IMAGE="aurora"

## SOURCE_SUFFIX arg should include a hyphen and the appropriate suffix name
# These examples all work for silverblue/kinoite/sericea/onyx/lazurite/vauxite/base
# - "-main"
# - "-nvidia"
# - "-asus"
# - "-asus-nvidia"
# - "-surface"
# - "-surface-nvidia"
#
# aurora, bazzite and bluefin each have unique suffixes. Please check the specific image.
# ucore has the following possible suffixes
# - stable
# - stable-nvidia
# - stable-zfs
# - stable-nvidia-zfs
# - (and the above with testing rather than stable)
ARG SOURCE_SUFFIX="-dx"

## SOURCE_TAG arg must be a version built for the specific image: eg, 39, 40, gts, latest
ARG SOURCE_TAG="latest"

# 1. extract Fedora Version
FROM ghcr.io/ublue-os/${SOURCE_IMAGE}${SOURCE_SUFFIX}:${SOURCE_TAG} as base

# read Version from Base-Image
RUN grep 'VERSION_ID=' /etc/os-release | cut -d '"' -f 2 > /fedora_version

### 2. SOURCE IMAGE
## this is a standard Containerfile FROM using the build ARGs above to select the right upstream image
FROM ghcr.io/ublue-os/${SOURCE_IMAGE}${SOURCE_SUFFIX}:${SOURCE_TAG}


### 3. MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.

COPY --from=base /fedora_version /tmp/fedora_version

RUN FEDORA_VERSION=$(cat /tmp/fedora_version) && \
    echo "Detected Fedora version: $FEDORA_VERSION" && \
    BASE_VERSION=$(echo $FEDORA_VERSION | sed 's/VERSION_ID=//') && \
    AKMODS_VERSION="main-$BASE_VERSION" && \
    echo "Using AKMODS version: $AKMODS_VERSION" && \
    echo $AKMODS_VERSION > /tmp/akmods_version

RUN AKMODS_VERSION=$(cat /tmp/akmods_version) && \
    echo "Final AKMODS version: $AKMODS_VERSION"

COPY --from=ghcr.io/ublue-os/akmods-extra:${AKMODS_VERSION} /rpms/ /tmp/rpms

RUN rpm-ostree install /tmp/rpms/kmods/kmod-evdi*.rpm

COPY build.sh /tmp/build.sh

RUN mkdir -p /var/lib/alternatives && \
    /tmp/build.sh && \
    ostree container commit
## NOTES:
# - /var/lib/alternatives is required to prevent failure with some RPM installs
# - All RUN commands must end with ostree container commit
#   see: https://coreos.github.io/rpm-ostree/container/#using-ostree-container-commit
