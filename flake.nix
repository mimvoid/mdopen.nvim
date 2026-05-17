{
  description = "Flake for mdopen.nvim";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      allSystems = nixpkgs.lib.genAttrs nixpkgs.lib.platforms.all;
      toSystems = passPkgs: allSystems (system: passPkgs (import nixpkgs { inherit system; }));
    in
    {
      packages = toSystems (pkgs: {
        default = pkgs.callPackage ./package.nix { };
      });

      overlay = _final: prev: {
        vimPlugins.mdopen-nvim = prev.pkgs.callPackage ./package.nix { };
      };

      devShells = toSystems (pkgs: {
        default = pkgs.mkShell {
          name = "mdopen.nvim";
          packages = [ pkgs.emmylua-ls ];
        };
      });
    };
}
