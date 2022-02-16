# Reproducbile Builds with Nix

**NOTE**: This is **Work in Progress**

The build process is not fully automated yet, and must be done in a shell.

Start the shell like so:

```console
nix develop --ignore-environment
```

Build the `cipher-paratime` binary:

```console
cargo build --release --target x86_64-fortanix-unknown-sgx
```

Convert an the `x86_64-fortanix-unknown-sgx` ELF binary to `SGXS`:

```console
# TODO put this in flake.nix or figure out what's the best way ...
export PATH=$PATH:~/.cargo/bin

cargo elf2sgxs --release
```

Check the hash ...

BLAKE2:

```console
b2sum target/x86_64-fortanix-unknown-sgx/release/cipher-paratime.sgxs
```
```console
5f10b2063d5621f66188651059b0ffdcc8501dead9da740c51684d3737acec310e23b5d2aa1f2c52bdd3e40e5222120f216a43fa6c09c7c186ec775e29c1731c  target/x86_64-fortanix-unknown-sgx/release/cipher-paratime.sgxs
```

SHA256:

```console
sha256sum target/x86_64-fortanix-unknown-sgx/release/cipher-paratime.sgxs
```

```console
022fae249bdc551122efd148868fd5c38bdaaf3f82aca697853c59681f48d446  target/x86_64-fortanix-unknown-sgx/release/cipher-paratime.sgxs
```
