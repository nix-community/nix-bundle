{
  stdenv,
  fetchFromGitHub,
  writeText,
  nix,
  cacert,
}:

stdenv.mkDerivation {
  name = "nix-installer";

  propagatedBuildInputs = [
    nix.out
    cacert
  ];

  buildCommand = ''
    mkdir -p $out/bin/
    substitute ${./install-nix-from-closure.sh} $out/install \
      --subst-var-by nix ${nix.out} \
      --subst-var-by cacert ${cacert}
    chmod +x $out/install
  '';
}
