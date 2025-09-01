{
  stdenv,
  lib,
  fetchurl,
  fuse,
  zlib,
  squashfsTools,
  glib,
}:

# This is from some binaries.

# Ideally, this should be source based,
# but I can't get it to build from GitHub

stdenv.mkDerivation rec {
  name = "appimagekit";

  src = fetchurl {
    url = "https://github.com/AppImage/AppImageKit/releases/download/10/appimagetool-x86_64.AppImage";
    sha256 = "03zbiblj8a1yk1xsb5snxi4ckwn3diyldg1jh5hdjjhsmpw652ig";
  };

  buildInputs = [
    squashfsTools
  ];

  sourceRoot = "squashfs-root";

  unpackPhase = ''
    cp $src appimagetool-x86_64.AppImage
    chmod u+wx appimagetool-x86_64.AppImage
    patchelf \
      --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
      --set-rpath ${fuse}/lib:${zlib}/lib \
      appimagetool-x86_64.AppImage

    ./appimagetool-x86_64.AppImage --appimage-extract
  '';

  installPhase = ''
    mkdir -p $out
    cp -r usr/* $out

    for x in $out/bin/*; do
      patchelf \
        --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
        --set-rpath ${
          lib.makeLibraryPath [
            zlib
            stdenv.cc.libc
            fuse
            glib
          ]
        } \
        $x
    done
  '';

  dontStrip = true;
  dontPatchELF = true;
}
