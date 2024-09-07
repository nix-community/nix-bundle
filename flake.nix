{
  description = "The purely functional package manager";

  inputs.nixpkgs.url = "nixpkgs/nixos-24.05-small";
  inputs.fakedir-pkgs.url = "github:nixie-dev/fakedir";

  outputs = { self, nixpkgs, fakedir-pkgs }: {
    bundlers = {
      nix-bundle = { program, system }: let
        nixpkgs' = nixpkgs.legacyPackages.${system};
        fakedir = fakedir-pkgs.packages.${system}.fakedir-universal;
        nix-bundle = import self { nixpkgs = nixpkgs'; inherit fakedir; };
        script-linux = nixpkgs'.writeScript "startup" ''
          #!/usr/bin/env bash
          exec .${nix-bundle.nix-user-chroot}/bin/nix-user-chroot -n ./nix -w "''${TMPX_RESTORE_PWD}" -- "$(dirname ${program})/$(basename "$0")" "$@"
        '';
        script-darwin = nixpkgs'.writeScript "startup" ''
          #!/usr/bin/env bash
          # use absolute paths so the environment variables don't get reinterpreted after a cd
          __TMPX_DAT_PATH=$(pwd)
          cd "''${TMPX_RESTORE_PWD}"
          export DYLD_INSERT_LIBRARIES="''${__TMPX_DAT_PATH}/lib/libfakedir.dylib"
          export FAKEDIR_PATTERN=/nix
          export FAKEDIR_TARGET="''${__TMPX_DAT_PATH}/nix"

          # make sure the fakedir libraries are loaded by running the command in bash within the bottle
          exec "''${__TMPX_DAT_PATH}/${nixpkgs'.bash}/bin/bash" -c "exec ''${__TMPX_DAT_PATH}$(dirname ${program})/$(basename "$0") $@"
        '';
        script = if nixpkgs'.stdenv.isDarwin then script-darwin else script-linux;
      in nix-bundle.makebootstrap {
        targets = [ script ];
        startup = script;
      };
    };

    defaultBundler = self.bundlers.nix-bundle;
  };
}
