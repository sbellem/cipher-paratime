{
  description = "A devShell example";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/9a3cfff2f9035ca0bd54ff13b608c4492eca6be3";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url = "github:numtide/flake-utils";
    fortanix-sgx-tools.url = "github:initc3/nix-fortanix?dir=fortanix-sgx-tools";
    sgxs-tools.url = "github:initc3/nix-fortanix?dir=sgxs-tools";
    oasis-core-tools.url = "github:sbellem/oasis-core/142c5daf74fecc5533fc50589b06b3117a509cb0";
  };

  outputs = {
    self,
    nixpkgs,
    rust-overlay,
    flake-utils,
    fortanix-sgx-tools,
    oasis-core-tools,
    sgxs-tools,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        overlays = [(import rust-overlay)];
        pkgs = import nixpkgs {
          inherit system overlays;
        };
      in
        with pkgs; {
          defaultPackage = rustPlatform.buildRustPackage rec {
            pname = "cipher-paratime";
            version = "2.0.0-alpha3";

            src = builtins.path {
              path = ./.;
              name = "${pname}-${version}";
            };

            cargoSha256 = "sha256-a6tMY2NLeIcMeU2bw9qCtgxD8odlpajzl9N28yZ9n38=";

            LIBCLANG_PATH = "${pkgs.llvmPackages_11.libclang.lib}/lib";

            rust_toolchain = rust-bin.fromRustupToolchainFile ./rust-toolchain;

            nativeBuildInputs = [
              oasis-core-tools.defaultPackage.${system}
              fortanix-sgx-tools.defaultPackage.${system}
              #sgxs-tools.defaultPackage.${system}
              clang_11
              #gcc
              #gcc_multi
              llvmPackages_11.libclang.lib
              #pkg-config
              (rust_toolchain.override {
                targets = ["x86_64-fortanix-unknown-sgx"];
              })
            ];

            #cargoBuildFlags = [ "--package oasis-core-tools" ];
            #cargoTestFlags = [ "--package oasis-core-tools" ];
            buildPhase = ''
              runHook preBuild

              cargo build --release --target x86_64-fortanix-unknown-sgx

              runHook postBuild
            '';

            postBuild = ''
              cargo elf2sgxs --release
            '';

            installPhase = ''
              runHook preInstall

              mkdir -p $out/bin
              cp -r target/x86_64-fortanix-unknown-sgx $out/bin/x86_64-fortanix-unknown-sgx

              runHook postInstall
            '';
          };

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
              pkg-config
              protobuf
              (rust-bin.nightly."2021-11-04".default.override {
                #extensions = [ "rust-src" "rustfmt" "rust-std" ];
                extensions = ["rustfmt"];
                targets = ["x86_64-fortanix-unknown-sgx"];
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
