{
  nixpkgs' ? <nixpkgs>,
}:

let
  pkgs = import nixpkgs' { };
  muslPkgs = import nixpkgs' {
    localSystem.config = "x86_64-unknown-linux-musl";
  };

in
rec {
  appimagetool = pkgs.callPackage ./appimagetool.nix { };

  appimage = pkgs.callPackage ./appimage.nix {
    inherit appimagetool;
  };

  appdir = pkgs.callPackage ./appdir.nix { inherit muslPkgs; };
}
