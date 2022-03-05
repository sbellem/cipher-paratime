FROM nixpkgs/nix-unstable

RUN mkdir -p ~/.config/nix \
        && echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
