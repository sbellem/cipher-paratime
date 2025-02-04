{
  description = "Oasis Network Cipher ParaTime";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/release-21.11";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.flake-utils.follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fortanix-sgx-tools = {
      url = "github:sbellem/fortanix-sgx-tools";
      inputs.flake-utils.follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-overlay.follows = "rust-overlay";
    };
    sgxs-tools = {
      url = "github:sbellem/sgxs-tools";
      inputs.flake-utils.follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-overlay.follows = "rust-overlay";
    };
    oasis-core-tools = {
      url = "github:sbellem/oasis-core/nix";
      inputs.flake-utils.follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-overlay.follows = "rust-overlay";
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

            # TODO: Make sure it's ok to drop "-isystem/usr/include/x86_64-linux-gnu"
            #
            # See nixpkgs manual sect 6.8
            #
            # 6.8. Purity in Nixpkgs
            # Measures taken to prevent dependencies on packages outside the
            # store, and what you can do to prevent them.
            #
            # GCC doesn’t search in locations such as /usr/include. In fact,
            # attempts to add such directories through the -I flag are
            # filtered out. Likewise, the linker (from GNU binutils) doesn’t
            # search in standard locations such as /usr/lib. Programs built on
            # Linux are linked against a GNU C Library that likewise doesn’t
            # search in the default system locations.
            CFLAGS_X86_64_FORTANIX_UNKNOWN_SGX = "-mlvi-hardening -mllvm -x86-experimental-lvi-inline-asm-hardening";
            CC_X86_64_FORTANIX_UNKNOWN_SGX = clang_11;

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
