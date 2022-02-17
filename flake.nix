{
  description = "A devShell example";

  inputs = {
    nixpkgs.url      = "github:nixos/nixpkgs/9a3cfff2f9035ca0bd54ff13b608c4492eca6be3";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url  = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, rust-overlay, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };
      in
      with pkgs;
      {
        devShell = mkShell {
          buildInputs = [
            bubblewrap
            clang_11
            exa
            fd
            gcc
            gcc_multi
            libseccomp
            llvmPackages_11.libclang.lib
            openssl
            pkgconfig
            protobuf
            (rust-bin.nightly."2021-11-04".default.override {
              #extensions = [ "rust-src" "rustfmt" "rust-std" ];
              extensions = [ "rustfmt" ];
              targets = [ "x86_64-fortanix-unknown-sgx" ];
            })
            unixtools.whereis
            which
            b2sum
          ];

          shellHook = ''
            alias ls=exa
            alias find=fd

            cargo install cargo-audit
            cargo install --version 0.4.0 fortanix-sgx-tools
            cargo install --version 0.8.2 sgxs-tools

            # needed for elf2sgxs
            cargo install oasis-core-tools \
              --git https://github.com/oasisprotocol/oasis-core \
              --force \
              --locked

            export LIBCLANG_PATH="${pkgs.llvmPackages_11.libclang.lib}/lib"
            export RUST_BACKTRACE=1

            # TODO: figure what's the "good" way to do this
            #export PATH=PATH:~/.cargo/bin
          '';
        };
      }
    );
}
