{
  description = "Deployment system";
  inputs = {
    nixpkgs.url = "github:miuirussia/nixpkgs/nixpkgs-unstable";
  };
  outputs = { self, nixpkgs, ... }:
    let
      version = builtins.substring 0 8 self.lastModifiedDate;
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; overlays = [ self.overlay ]; });
    in
    rec {
      overlay = final: prev: {
        generateApps = flake:
          let
            machines = builtins.attrNames flake.nixosConfigurations;
            validMachines = final.lib.remove "" (final.lib.forEach machines (x: final.lib.optionalString (flake.nixosConfigurations."${x}"._module.args ? deploy) "${x}"));
            mkDeployScript = { machine, dryRun }:
              let
                inherit (builtins) abort;

                deploy = flake.nixosConfigurations.${machine}._module.args.deploy;
                user = deploy.sshUser or "root";
                host = deploy.host;
                where = deploy.buildOn or "remote";
                options = deploy.options or [ ];
                remote = if where == "remote" then true else if where == "local" then false else abort "_module.args.deploy.buildOn is not set to a valid value of 'local' or 'remote'";
                switch = if dryRun then "dry-activate" else "switch";
                script = ''
                  set -e
                  echo "Deploy script v${version} "
                  echo "Deploying nixosConfigurations.${machine} from ${flake}"
                  echo "SSH User: ${user}"
                  echo "SSH Host: ${host}"
                '' + (if remote then ''
                  echo "Sending flake to ${machine} via nix copy:"
                  ( set -x; ${final.nix}/bin/nix copy ${flake} --to ssh://${user}@${host} )
                  echo "Activating configuration on ${machine} via ssh:"
                  ( set -x; ${final.openssh}/bin/ssh -t ${user}@${host} 'sudo nixos-rebuild ${switch} --flake ${flake}#${machine} ${nixpkgs.lib.concatStringsSep " " options}' )
                '' else ''
                  echo "Building system closure locally, copying it to remote store and activating it:"
                  ( set -x; NIX_SSHOPTS="-t" ${final.nixos-rebuild}/bin/nixos-rebuild ${switch} --flake ${flake}#${machine} --target-host ${user}@${host} --use-remote-sudo )
                '');
              in
              final.writeScript "deploy-${machine}.sh" script;
          in
          {
            deploy =
              (
                nixpkgs.lib.genAttrs
                  validMachines
                  (x:
                    {
                      type = "app";
                      program = toString (mkDeployScript {
                        machine = x;
                        dryRun = false;
                      });
                    }
                  )
                // nixpkgs.lib.genAttrs
                  (map (a: a + "-dry-run") validMachines)
                  (x:
                    {
                      type = "app";
                      program = toString (mkDeployScript {
                        machine = x;
                        dryRun = true;
                      });
                    }
                  )
              );
          };
      };
      deploy = forAllSystems (system: nixpkgsFor.${system}.generateApps);
    };
}
