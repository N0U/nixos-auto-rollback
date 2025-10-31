{ lib, pkgs ? import <nixpkgs> {} }:

pkgs.stdenv.mkDerivation {
  pname = "auto-rollback";
  version = "1.0";
  src = ./.;
  # src = pkgs.fetchFromGitHub { # Example: fetching source from GitHub
  #   owner = "N0U";
  #   repo = "nixos-auto-rollback";
  #   rev = "0d4b6d97f0f8f4c8a399d2953c3b6f6820fe9578";
  #   hash = "sha256-VPWjFmQ6cJLSJofRLCiLyijatll4+mNQvDqUHHs+Kvo=";
  # };
  nativeBuildInputs = [
    pkgs.makeWrapper
    # pkgs.nixos-rebuild
    pkgs.yq-go
    pkgs.gawkInteractive
    pkgs.iputils
    pkgs.bash
  ];

  dontPatch = true;
  dontBuild = true;
  dontFixup = true;

  installPhase = ''
    mkdir -p "$out/bin"
    cp -a src/. "$out/bin"
    chmod +x "$out/bin/main.sh"
    patchShebangs "$out/bin"
    makeWrapper "$out/bin/main.sh" "$out/bin/auto-rollback.sh" \
      --prefix PATH : ${
      lib.makeBinPath [
        # pkgs.nixos-rebuild
        pkgs.yq-go
        pkgs.gawkInteractive
        pkgs.iputils
        pkgs.bash
      ]
    }
    chmod +x "$out/bin/auto-rollback.sh"
  '';

  meta = with pkgs.lib; {
    description = "Auto rollback script to rollback system in case of failure of essential services";
    homepage = "https://github.com/N0U/nixos-auto-rollback";
    platforms = platforms.linux;
  };
}

