{
  appimagefile,
  nixpkgs' ? <nixpkgs>,
}:

# nix build -f test-appimage.nix --arg appimagefile ./VLC*AppImage

with import nixpkgs' { };

runCommandCC "patchelf" { } ''
  cp ${appimagefile} $out
  chmod +w $out
  patchelf \
    --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
    --set-rpath ${
      lib.makeLibraryPath [
        stdenv.cc.libc
        fuse
        zlib
        glib
      ]
    }
    $out
''
