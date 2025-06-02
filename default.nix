{
  nixpkgs,
}:

with nixpkgs;

rec {
  toArxArchX =
    {
      drvToBundle,
      pkgsTarget,
    }:
    let
      programPath = lib.getExe' drvToBundle (
        drvToBundle.meta.mainProgram or (lib.warn
          "nix-bundle: Package ${
            lib.strings.escapeNixIdentifier drvToBundle.meta.name or drvToBundle.pname or drvToBundle.name
          } does not have the meta.mainProgram attribute. Assuming you want '${lib.getName drvToBundle}'."
          lib.getName
          drvToBundle
        )
      );
      script = writeScript "startup" ''
        #!/bin/sh
        .${pkgsTarget.nix-user-chroot}/bin/nix-user-chroot -n ./nix -- ${programPath} "$@"
      '';
    in
    makebootstrap {
      inherit drvToBundle;
      targets = [ script ];
      startup = ".${builtins.unsafeDiscardStringContext script} '\"$@\"'";
    };

  toStorePath =
    target:
    # If a store path has been given but is not a derivation, add the missing context
    # to it so it will be propagated properly as a build input.
    if !(lib.isDerivation target) && lib.isStorePath target then
      let
        path = toString target;
      in
      builtins.appendContext path {
        "${path}" = {
          path = true;
        };
      }
    # Otherwise, add to the store. This takes care of appending the store path
    # in the context automatically.
    else
      "${target}";

  arx =
    {
      drvToBundle,
      archive,
      startup,
    }:
    stdenv.mkDerivation {
      name = if drvToBundle != null then "${drvToBundle.pname}-arx" else "arx";
      passthru = {
        inherit drvToBundle;
      };
      buildCommand = ''
        # tmpdir has a additional `/` in the beginning to work around `QualifiedPath` checking for `|/|./|../|`
        ${haskellPackages.arx}/bin/arx tmpx \
          --tmpdir '/$HOME/.cache' \
          --shared \
          -rm! ${archive} \
          -o $out // ${startup}
        chmod +x $out
      '';
    };

  maketar =
    { targets }:
    stdenv.mkDerivation {
      name = "maketar";
      buildInputs = [ perl ];
      exportReferencesGraph = map (x: [
        ("closure-" + baseNameOf x)
        x
      ]) targets;
      buildCommand = ''
        storePaths=$(perl ${pathsFromGraph} ./closure-*)

        # https://reproducible-builds.org/docs/archives
        tar -cf - \
          --owner=0 --group=0 --mode=u+rw,uga+r \
          --hard-dereference \
          --mtime="@$SOURCE_DATE_EPOCH" \
          --format=gnu \
          --sort=name \
          $storePaths | bzip2 -z > $out
      '';
    };

  makebootstrap =
    {
      targets,
      startup,
      drvToBundle ? null,
    }:
    arx {
      inherit drvToBundle startup;
      archive = maketar {
        inherit targets;
      };
    };

  makeStartup =
    {
      target,
      nixUserChrootFlags,
      nix-user-chroot',
      run,
      initScript,
    }:
    let
      # Avoid re-adding a store path into the store
      path = toStorePath target;
    in
    writeScript "startup" ''
      #!/bin/sh
      ${initScript}
      .${nix-user-chroot'}/bin/nix-user-chroot -n ./nix ${nixUserChrootFlags} -- ${path}${run} "$@"
    '';

  nix-bootstrap =
    {
      target,
      extraTargets ? [ ],
      run,
      nix-user-chroot' ? nix-user-chroot,
      nixUserChrootFlags ? "",
      initScript ? "",
    }:
    let
      script = makeStartup {
        inherit
          target
          nixUserChrootFlags
          nix-user-chroot'
          run
          initScript
          ;
      };
    in
    makebootstrap {
      startup = ".${script} '\"$@\"'";
      targets = [ "${script}" ] ++ extraTargets;
    };

  nix-bootstrap-nix =
    {
      target,
      run,
      extraTargets ? [ ],
    }:
    nix-bootstrap-path {
      inherit target run;
      extraTargets = [
        gnutar
        bzip2
        xz
        gzip
        coreutils
        bash
      ] ++ extraTargets;
    };

  # special case adding path to the environment before launch
  nix-bootstrap-path =
    let
      nix-user-chroot'' =
        targets:
        nix-user-chroot.overrideDerivation (o: {
          buildInputs = o.buildInputs ++ targets;
          makeFlags = o.makeFlags ++ [
            ''ENV_PATH="${lib.makeBinPath targets}"''
          ];
        });
    in
    {
      target,
      extraTargets ? [ ],
      run,
      initScript ? "",
    }:
    nix-bootstrap {
      inherit
        target
        extraTargets
        run
        initScript
        ;
      nix-user-chroot' = nix-user-chroot'' extraTargets;
    };
}
