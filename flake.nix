{
  description = "A devShell example";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url = "github:numtide/flake-utils";
    fortanix-sgx-tools = {
      url = "github:initc3/nix-fortanix?dir=fortanix-sgx-tools";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sgxs-tools = {
      url = "github:initc3/nix-fortanix?dir=sgxs-tools";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    oasis-core-tools = {
      url = "github:sbellem/oasis-core/142c5daf74fecc5533fc50589b06b3117a509cb0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
    flake-utils.lib.eachSystem ["x86_64-linux"] (
      system: let
        overlays = [(import rust-overlay)];
        pkgs = import nixpkgs {
          inherit system overlays;
        };

        pname = "cipher-paratime";
        version = "2.0.1-alpha1";

        src = builtins.path {
          path = ./.;
          name = "${pname}-${version}";
        };

        cargoSha256 = "sha256-r3GpzZ/G+yLxJFcAFjIfFv6sENxlIVf5UQz/AXJ8y8Y=";

        LIBCLANG_PATH = "${pkgs.llvmPackages_11.libclang.lib}/lib";
        rust_toolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain;

        _nativeBuildInputs = with pkgs; [
          clang_11
          fortanix-sgx-tools.defaultPackage.${system}
          llvmPackages_11.libclang.lib
          oasis-core-tools.defaultPackage.${system}
        ];
      in
        with pkgs; {
          packages.nosgx = rustPlatform.buildRustPackage rec {
            inherit pname version src cargoSha256 LIBCLANG_PATH rust_toolchain _nativeBuildInputs;

            nativeBuildInputs = _nativeBuildInputs ++ [rust_toolchain];
          };

          packages.sgx = rustPlatform.buildRustPackage rec {
            inherit pname version src cargoSha256 LIBCLANG_PATH rust_toolchain _nativeBuildInputs;

            nativeBuildInputs =
              _nativeBuildInputs
              ++ [
                (rust_toolchain.override {
                  targets = ["x86_64-fortanix-unknown-sgx"];
                })
              ];

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
              cp target/x86_64-fortanix-unknown-sgx/release/cipher-paratime.sgxs $out/bin/

              runHook postInstall
            '';
          };

          defaultPackage = self.packages.${system}.nosgx;

          devShell = mkShell {
            inherit LIBCLANG_PATH rust_toolchain _nativeBuildInputs;

            buildInputs =
              _nativeBuildInputs
              ++ [
                exa
                fd
                gcc
                gcc_multi
                libseccomp
                openssl
                pkg-config
                protobuf
                (rust_toolchain.override {
                  targets = ["x86_64-fortanix-unknown-sgx"];
                })
                sgxs-tools.defaultPackage.${system}
                unixtools.whereis
                which
                b2sum
              ];

            shellHook = ''
              alias ls=exa
              alias find=fd
              export RUST_BACKTRACE=1
            '';
          };
        }
    );
}
