{
  description = "The purely functional package manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs =
    inputs:
    let
      inherit (inputs.nixpkgs) lib;

      getExe =
        x:
        lib.getExe' x (
          x.meta.mainProgram or (lib.warn
            "nix-bundle: Package ${
              lib.strings.escapeNixIdentifier x.meta.name or x.pname or x.name
            } does not have the meta.mainProgram attribute. Assuming you want '${lib.getName x}'."
            lib.getName
            x
          )
        );
    in
    inputs.utils.lib.eachDefaultSystem (
      system:
      let
        nix-bundle-fun =
          {
            drv,
            programPath ? getExe drv,
          }:
          let
            nixpkgs = inputs.nixpkgs.legacyPackages.${system};
            nix-bundle = import inputs.self { inherit nixpkgs; };
            script = nixpkgs.writeScript "startup" ''
              #!/bin/sh
              .${nix-bundle.nix-user-chroot}/bin/nix-user-chroot -n ./nix -- ${programPath} "$@"
            '';
          in
          nix-bundle.makebootstrap {
            drvToBundle = drv;
            targets = [ script ];
            startup = ".${builtins.unsafeDiscardStringContext script} '\"$@\"'";
          };
      in
      {
        bundlers = {
          default = inputs.self.bundlers.${system}.nix-bundle;
          nix-bundle = drv: nix-bundle-fun { inherit drv; };
        };

        formatter = inputs.nixpkgs.legacyPackages.${system}.nixfmt-tree;
      }
    );
}
