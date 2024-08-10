{
  nixpkgs ? import <nixpkgs> {}
, fakedir ? import (fetchTarball "https://github.com/nixie-dev/fakedir/archive/b0f70b805aa86fe881eeca642f12069c7983a8e7.tar.gz") {}
}:

with nixpkgs;

let
  arx' = haskellPackages.arx.overrideAttrs (o: {
    patches = (o.patches or []) ++ [./arx-multi-bin.patch];
  });
in rec {
  toStorePath = target:
    # If a store path has been given but is not a derivation, add the missing context
    # to it so it will be propagated properly as a build input.
    if !(lib.isDerivation target) && lib.isStorePath target then
      let path = toString target; in
      builtins.appendContext path { "${path}" = { path = true; }; }
    # Otherwise, add to the store. This takes care of appending the store path
    # in the context automatically.
    else "${target}";

  arx = { archive, startup}:
    stdenv.mkDerivation {
      name = "arx";
      buildCommand = ''
        ${arx'}/bin/arx tmpx --shared -rm! ${archive} -o $out -e ${startup}
        chmod +x $out
      '';
    };

  maketar = { targets }:
    stdenv.mkDerivation {
      name = "maketar";
      buildInputs = [ perl gnutar ];
      exportReferencesGraph = map (x: [("closure-" + baseNameOf x) x]) targets;
      buildCommand = let
        additionalPaths = lib.optionalString stdenv.isDarwin "-C ${fakedir} lib";
      in ''
        storePaths=$(perl ${pathsFromGraph} ./closure-*)

        tar -cf - \
          --owner=0 --group=0 --mode=u+rw,uga+r \
          --hard-dereference \
          $storePaths ${additionalPaths} | bzip2 -z > $out
      '';
    };

  # TODO: eventually should this go in nixpkgs?
  nix-user-chroot = lib.makeOverridable stdenv.mkDerivation {
    name = "nix-user-chroot-2c52b5f";
    src = ./nix-user-chroot;

    buildInputs = [
      stdenv.cc.cc.libgcc or null
    ];

    makeFlags = [];

    # hack to use when /nix/store is not available
    postFixup = ''
      exe=$out/bin/nix-user-chroot
      patchelf \
        --set-interpreter .$(patchelf --print-interpreter $exe) \
        --set-rpath $(patchelf --print-rpath $exe | sed 's|/nix/store/|./nix/store/|g') \
        $exe
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin/
      cp nix-user-chroot $out/bin/nix-user-chroot

      runHook postInstall
    '';

    meta.platforms = lib.platforms.linux;
  };

  makebootstrap = { targets, startup }:
    arx {
      inherit startup;
      archive = maketar {
        inherit targets;
      };
    };

  makeStartup = { target, nixUserChrootFlags, nix-user-chroot', run, initScript }:
  let
    # Avoid re-adding a store path into the store
    path = toStorePath target;
    script-linux = ''
      exec .${nix-user-chroot'}/bin/nix-user-chroot -n ./nix ${nixUserChrootFlags} -- ".$(basename "$0")/$(dirname ${path}${run})" "$@"
    '';
    script-macos = ''
      # use absolute paths so the environment variables don't get reinterpreted after a cd
      __TMPX_DAT_PATH=$(pwd)
      cd "''${TMPX_RESTORE_PWD}"
      export DYLD_INSERT_LIBRARIES="''${__TMPX_DAT_PATH}/lib/libfakedir.dylib"
      export FAKEDIR_PATTERN=/nix
      export FAKEDIR_TARGET="''${__TMPX_DAT_PATH}/nix"

      exec "''${__TMPX_DAT_PATH}$(basename "$0")/$(dirname ${path}${run})/$(basename "$0")" "$@"
    '';
    script = if stdenv.isDarwin then script-macos else script-linux;
  in
  writeScript "startup" ''
    #!/bin/sh
    ${initScript}
    ${script}
  '';

  nix-bootstrap = { target, extraTargets ? [], run, nix-user-chroot' ? nix-user-chroot, nixUserChrootFlags ? "", initScript ? "" }:
    let
      script = makeStartup { inherit target nixUserChrootFlags nix-user-chroot' run initScript; };
    in makebootstrap {
      startup = script;
      targets = [ "${script}" ] ++ extraTargets;
    };

  nix-bootstrap-nix = {target, run, extraTargets ? []}:
    nix-bootstrap-path {
      inherit target run;
      extraTargets = [ gnutar bzip2 xz gzip coreutils bash ];
    };

  # special case adding path to the environment before launch
  nix-bootstrap-path = let
    nix-user-chroot'' = targets: nix-user-chroot.overrideDerivation (o: {
      buildInputs = o.buildInputs ++ targets;
      makeFlags = o.makeFlags ++ [
        ''ENV_PATH="${lib.makeBinPath targets}"''
      ];
    }); in { target, extraTargets ? [], run, initScript ? "" }: nix-bootstrap {
      inherit target extraTargets run initScript;
      nix-user-chroot' = nix-user-chroot'' extraTargets;
    };
}
