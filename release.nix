{
  nixpkgs ? <nixpkgs>,
  nixpkgs' ? import nixpkgs { },
}:
with nixpkgs';

stdenv.mkDerivation rec {
  pname = "nix-bundle";
  name = "${pname}-${version}";
  version = "0.4.0";

  src = ./.;

  # coreutils, gnutar is actually needed by nix for bootstrap
  buildInputs = [
    nix
    coreutils
    makeWrapper
    gnutar
    gzip
    bzip2
  ];

  nixBundlePath = lib.makeBinPath [
    nix
    coreutils
    gnutar
    gzip
    bzip2
  ];
  nixRunPath = lib.makeBinPath [
    nix
    coreutils
  ];

  makeFlags = [ "PREFIX=$(out)" ];

  postInstall = ''
    mkdir -p $out/bin
    makeWrapper $out/share/nix-bundle/nix-bundle.sh $out/bin/nix-bundle \
      --prefix PATH : ${nixBundlePath}
    makeWrapper $out/share/nix-bundle/nix-run.sh $out/bin/nix-run \
      --prefix PATH : ${nixRunPath}
  '';

  meta = with lib; {
    maintainers = [ maintainers.matthewbauer ];
    platforms = platforms.all;
    description = "Create bundles from Nixpkgs attributes";
    license = licenses.mit;
    homepage = "https://github.com/matthewbauer/nix-bundle";
  };
}
