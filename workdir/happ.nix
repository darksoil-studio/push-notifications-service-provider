{ inputs, ... }:

{
  # Import all `../dnas/*/dna.nix` files
  imports = (map (m: "${./..}/dnas/${m}/dna.nix") (builtins.attrNames
    (if builtins.pathExists ./dnas then builtins.readDir ./dnas else { })));

  perSystem = { inputs', lib, self', system, ... }: {
    packages.push_notifications_service_provider_test_happ =
      inputs.tnesh-stack.outputs.builders.${system}.happ {
        happManifest = ./happ.yaml;

        dnas = {
          # Include here the DNA packages for this hApp, e.g.:
          # my_dna = inputs'.some_input.packages.my_dna;
          # This overrides all the "bundled" properties for the hApp manifest 
          push_notifications_service_providers_manager =
            self'.packages.push_notifications_service_providers_manager;
          push_notifications_service =
            self'.packages.push_notifications_service;
          happ_care_service = self'.packages.happ_care_service;
        };
      };
  };
}
