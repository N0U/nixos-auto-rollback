{ pkgs ? import <nixpkgs> {} }:

pkgs.stdenv.mkDerivation {
  pname = "auto-rollback";
  version = "1.0";
  src = pkgs.fetchFromGitHub { # Example: fetching source from GitHub
    url = "https://github.com/N0U/nixos-auto-rollback";
    sha256 = "sha256-bdcb92f6e9b82a686f83240202c640d3221936d5";
  };
  nativeBuildInputs = [ yq-go ];
  
  dontPatch = true;
  dontBuild = true;
  dontFixup = true;

  installPhase = ''
    mkdir -p $out/bin
    cp auto-rollback.sh $out/bin/auto-rollback.sh
    cp util.sh $out/bin/util.sh
    chmod +x $out/bin/auto-rollback.sh
  '';

  meta = with pkgs.lib; {
    description = "Auto rollback script to rollback system in case of failure of essential services";
    homepage = "https://github.com/N0U/nixos-auto-rollback";
    platforms = platforms.linux;
  };
}


