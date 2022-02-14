FROM rust as base

ENV RUST_BACKTRACE=1

RUN apt-get update && apt-get install --yes \
                bubblewrap \
                cmake \
                gcc \
                g++ \
                gcc-multilib \
                make \
                libclang-dev \
                libseccomp-dev \
                libssl-dev \
                pkg-config \
                protobuf-compiler \
        && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/cipher-paratime

COPY rust-toolchain ./

RUN rustup component add rustfmt \
        && cargo install cargo-audit

RUN rustup target add x86_64-fortanix-unknown-sgx \
        && cargo install --version 0.4.0 fortanix-sgx-tools \
        && cargo install --version 0.8.2 sgxs-tools

# needed for elf2sgxs
RUN cargo install oasis-core-tools \
        --git https://github.com/oasisprotocol/oasis-core \
        --force \
        --locked

COPY Cargo.lock Cargo.toml .rustfmt.toml ./
COPY .cargo .cargo
COPY src src

RUN cargo build --release --target x86_64-fortanix-unknown-sgx
RUN cargo elf2sgxs --release
