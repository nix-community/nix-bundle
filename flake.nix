{
  description = "The purely functional package manager";

  inputs.nixpkgs.url = "nixpkgs/nixos-24.05-small";
  inputs.fakedir-pkgs.url = "github:nixie-dev/fakedir";

  outputs = { self, nixpkgs, fakedir-pkgs }: let
    systems = [ "x86_64-linux" "i686-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
  in {
    bundlers = {
      nix-bundle = { program, system }: let
        nixpkgs' = nixpkgs.legacyPackages.${system};
        fakedir = fakedir-pkgs.packages.${system}.fakedir-universal;
        nix-bundle = import self { nixpkgs = nixpkgs'; inherit fakedir; };
        script-linux = nixpkgs'.writeScript "startup" ''
          #!/bin/sh
          .${nix-bundle.nix-user-chroot}/bin/nix-user-chroot -n ./nix -- ${program} "$@"
        '';
        script-darwin = nixpkgs'.writeScript "startup" ''
          #!/bin/sh
          # use absolute paths so the environment variables don't get reinterpreted after a cd
          cur_dir=$(pwd)
          export DYLD_INSERT_LIBRARIES="''${cur_dir}/lib/libfakedir.dylib"
          export FAKEDIR_PATTERN=/nix
          export FAKEDIR_TARGET="''${cur_dir}/nix"
          exec .${program} "$@"
        '';
        script = if nixpkgs'.stdenv.isDarwin then script-darwin else script-linux;
      in nix-bundle.makebootstrap {
        targets = [ script ];
        startup = ".${builtins.unsafeDiscardStringContext script} '\"$@\"'";
      };
    };

    defaultBundler = self.bundlers.nix-bundle;
  };
}
