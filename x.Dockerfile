FROM ubuntu:20.04

# Package versions.
ARG RUST_NIGHTLY_VERSION=2021-11-04
ARG FORTANIX_TOOLS_VERSION=0.4.0
ARG SGXS_TOOLS_VERSION=0.8.2

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update -qq && apt-get install -qq \
                git \
                gcc \
                curl \
                jq \
                pkg-config \
                libssl-dev \
                protobuf-compiler \
                libclang-dev \
                clang-11 \
                gcc-multilib \
        && rm -rf /var/cache/apt/archives/*

RUN mkdir -p /cargo/.rustup

ENV HOME="/root"
#ENV GOPATH="/go"
ENV CARGO_HOME="/cargo"
ENV RUSTUP_HOME="/cargo/.rustup"
ENV PATH="${CARGO_HOME}/bin:${GOPATH}/bin:/usr/local/go/bin:${PATH}"

# Install Rust.
RUN curl "https://sh.rustup.rs" -sfo rustup.sh && \
    sh rustup.sh -y --default-toolchain nightly-${RUST_NIGHTLY_VERSION} && \
    rustup target add x86_64-fortanix-unknown-sgx && \
    cargo install --version ${FORTANIX_TOOLS_VERSION} fortanix-sgx-tools && \
    cargo install --version ${SGXS_TOOLS_VERSION} sgxs-tools && \
    rm -rf /cargo/registry /rustup.sh

# Install extra tools from oasis-core.
#RUN cd /usr/local/src && \
#    curl -OL https://github.com/oasisprotocol/oasis-core/archive/${OASIS_CORE_COMMIT}.tar.gz && \
#    tar -xzf ${OASIS_CORE_COMMIT}.tar.gz && \
#    cd oasis-core-* && \
#    cargo install --locked --force --path tools && \
#    cd .. && \
#    rm -rf ${OASIS_CORE_COMMIT}.tar.gz oasis-core-* && \
#    rm -rf /cargo/registry

# needed for elf2sgxs
RUN cargo install oasis-core-tools \
        --git https://github.com/oasisprotocol/oasis-core \
        --force \
        --locked

WORKDIR /usr/src/cipher-paratime
COPY .cargo .cargo
COPY Cargo.lock Cargo.toml .rustfmt.toml rust-toolchain ./
COPY src src
RUN cargo build --release --target x86_64-fortanix-unknown-sgx
RUN cargo elf2sgxs --release
