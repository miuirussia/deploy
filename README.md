# Deploy

## Usage

To add and configure `deploy` in your own flake, you need to:

1. Add the result of `deploy self` to the `apps` attribute of your flake.
2. Add and configure `_module.args.deploy` to the `nixosConfigurations` you want to deploy

Below is a minimal example:

```nix
{
  inputs = {
    nixpkgs.url = "github:miuirussia/nixpkgs/nixpkgs-unstable";
    deployment.url = "github:miuirussia/deploy";
  };

  outputs = { self, nixpkgs, deployment }: {
    apps = deployment.deploy.x86_64-linux self;
    nixosConfigurations = {
      myMachine = nixpkgs.lib.nixosSystem {
        modules = [
          (import ./my-configuration.nix)
          {
            _module.args.deploy = {
              host = "example.com";
              sshUser = "example";
              buildOn = "remote"; # valid args are "local" or "remote"
            };
          }
          # ... other configuration ...
        ];
      };
    };
  };
}
```

Each `nixosConfiguration` you have configured should have a deployment script in
`apps.deploy`, visible in `nix flake show` like this:

```
$ nix flake show 
git+file:///etc/nixos
├───apps
│   └───deploy
│       └───myMachine: app
└───nixosConfigurations
    └───myMachine: NixOS configuration
```

To finally execute the deployment script, use `nix run .#apps.deploy.myMachine`
