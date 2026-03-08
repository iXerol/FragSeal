ARG SWIFT_IMAGE=swift:6.2
FROM ${SWIFT_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    clang \
    curl \
    git \
    jq \
    lld \
    libxml2-dev \
    libssl-dev \
    pkg-config \
    python3 \
    unzip \
    xxd \
    zip \
    && rm -rf /var/lib/apt/lists/*

ARG TARGETARCH
RUN set -eux; \
    arch="${TARGETARCH:-$(dpkg --print-architecture)}"; \
    case "${arch}" in \
      amd64|x86_64) bazelisk_arch="amd64" ;; \
      arm64|aarch64) bazelisk_arch="arm64" ;; \
      *) echo "Unsupported architecture: ${arch}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /usr/local/bin/bazel "https://github.com/bazelbuild/bazelisk/releases/download/v1.22.1/bazelisk-linux-${bazelisk_arch}"; \
    chmod +x /usr/local/bin/bazel; \
    bazel --version

ENV CC=clang
ENV CXX=clang++
ENV BAZELISK_HOME=/var/cache/bazelisk

WORKDIR /workspace

ENTRYPOINT ["/bin/bash", "-lc"]
CMD ["exec /bin/bash"]
