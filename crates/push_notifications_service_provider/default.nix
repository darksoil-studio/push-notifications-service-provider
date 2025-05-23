{ inputs, self, ... }:

{
  perSystem = { inputs', pkgs, self', lib, system, ... }:
    let
      SERVICE_PROVIDER_HAPP =
        self'.packages.push_notifications_service_provider_happ.meta.debug;
      END_USER_HAPP =
        (inputs.holochain-nix-builders.outputs.builders.${system}.happ {
          happManifest = builtins.toFile "happ.yaml" ''
            ---
            manifest_version: "1"
            name: test_happ
            description: ~
            roles:   
              - name: service_providers
                provisioning:
                  strategy: create
                  deferred: false
                dna:
                  bundled: ""
                  modifiers:
                    network_seed: ~
                    properties: ~
                    origin_time: ~
                  version: ~
                  clone_limit: 100000
          '';

          dnas = {
            service_providers =
              inputs'.service-providers.packages.service_providers_dna;
          };
        }).meta.debug;
      INFRA_PROVIDER_HAPP =
        (inputs.holochain-nix-builders.outputs.builders.${system}.happ {
          happManifest = builtins.toFile "happ.yaml" ''
            ---
            manifest_version: "1"
            name: infra_provider_test_happ
            description: ~
            roles:   
              - name: push_notifications_service
                provisioning:
                  strategy: create
                  deferred: false
                dna:
                  bundled: ""
                  modifiers:
                    network_seed: ~
                    properties: ~
                    origin_time: ~
                  version: ~
                  clone_limit: 0
          '';

          dnas = {
            push_notifications_service =
              self'.builders.push_notifications_service_dna {
                clone_manager_provider = false;
              };
          };
        }).meta.debug;

      HAPP_DEVELOPER_HAPP =
        (inputs.holochain-nix-builders.outputs.builders.${system}.happ {
          happManifest = builtins.toFile "happ.yaml" ''
            ---
            manifest_version: "1"
            name: happ_developer_test_happ
            description: ~
            roles:   
              - name: service_providers
                provisioning:
                  strategy: create
                  deferred: false
                dna:
                  bundled: ""
                  modifiers:
                    network_seed: ~
                    properties: ~
                    origin_time: ~
                  version: ~
                  clone_limit: 100000
          '';

          dnas = {
            service_providers =
              inputs'.service-providers.packages.service_providers_dna;
          };
        }).meta.debug;

      craneLib = inputs.crane.mkLib pkgs;
      src = craneLib.cleanCargoSource (craneLib.path self.outPath);

      cratePath = ./.;

      cargoToml =
        builtins.fromTOML (builtins.readFile "${cratePath}/Cargo.toml");
      crate = cargoToml.package.name;
      pname = crate;
      version = cargoToml.package.version;

      commonArgs = {
        inherit src version pname;
        doCheck = false;
        buildInputs =
          inputs.holochain-nix-builders.outputs.dependencies.${system}.holochain.buildInputs;
      };
      cargoArtifacts = craneLib.buildDepsOnly commonArgs;
      binary =
        craneLib.buildPackage (commonArgs // { inherit cargoArtifacts; });
      check = craneLib.buildPackage (commonArgs // {
        inherit cargoArtifacts;
        doCheck = true;
        __noChroot = true;
        # RUST_LOG = "info";
        WASM_LOG = "info";
        # For the integration test
        inherit END_USER_HAPP INFRA_PROVIDER_HAPP SERVICE_PROVIDER_HAPP
          HAPP_DEVELOPER_HAPP;
      });
    in rec {

      builders.push-notifications-service-provider = { progenitors }:
        let
          progenitorsArg = builtins.toString
            (builtins.map (p: " --progenitors ${p}") self.outputs.progenitors);

          binaryWithDebugHapp =
            pkgs.runCommandLocal "push-notifications-service-provider" {
              buildInputs = [ pkgs.makeWrapper ];
            } ''
              mkdir $out
              mkdir $out/bin
              DNA_HASHES=test
              makeWrapper ${binary}/bin/push-notifications-service-provider $out/bin/push-notifications-service-provider \
                --add-flags "${self'.packages.push_notifications_service_provider_happ.meta.debug} --app-id $DNA_HASHES ${progenitorsArg}"
            '';
          binaryWithHapp =
            pkgs.runCommandLocal "push-notifications-service-provider" {
              buildInputs = [ pkgs.makeWrapper ];
              meta.debug = binaryWithDebugHapp;
            } ''
              mkdir $out
              mkdir $out/bin
              DNA_HASHES=$(cat ${self'.packages.push_notifications_service_provider_happ.dna_hashes})
              makeWrapper ${binary}/bin/push-notifications-service-provider $out/bin/push-notifications-service-provider \
                --add-flags "${self'.packages.push_notifications_service_provider_happ} --app-id $DNA_HASHES ${progenitorsArg}"
            '';
        in binaryWithHapp;

      packages.test-push-notifications-service-provider =
        builders.push-notifications-service-provider {
          progenitors =
            [ "uhCAk13OZ84d5HFum5PZYcl61kHHMfL2EJ4yNbHwSp4vn6QeOdFii" ];
        };

      checks.send-push-notification-test = check;
    };
}
