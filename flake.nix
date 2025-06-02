{
  description = "The purely functional package manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      ...
    }@inputs:

    {
      overlays.default = import ./overlays/default.nix;
    }
    // inputs.utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import inputs.nixpkgs {
          system = "${system}";
          overlays = [
            inputs.self.overlays.default
          ];
        };
        nix-bundle-lib = import inputs.self { nixpkgs = pkgs; };
      in
      {
        bundlers = {
          default = inputs.self.bundlers.${system}.toArx;
          toArx =
            drvToBundle:
            nix-bundle-lib.toArxArchX {
              inherit drvToBundle;
              pkgsTarget = pkgs;
            };
          toArxArm64Cross =
            drvToBundle:
            nix-bundle-lib.toArxArchX {
              inherit drvToBundle;
              pkgsTarget = pkgs.pkgsCross.aarch64-multiplatform;
            };
          identity = drv: drv;
        };
      }
    );
}
