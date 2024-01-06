{
  description = "DTLS/QUIC in luvit";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11";
    luvitpkgs = {
      url = "github:aiverson/luvit-nix";
      # necessary to be able to replace openssl buildinput from luvi
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, luvitpkgs }:
    let
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

    in
    {

      devShells = forAllSystems (system: { default = self.packages.${system}.devShell; });

      formatter = forAllSystems (system: self.packages.${system}.formatter);

      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };

          lit = luvitpkgs.packages.${system}.lit;
          luvi = luvitpkgs.packages.${system}.luvi;
          luviBase = luvitpkgs.lib.${system}.luviBase;
          luvit = luvitpkgs.packages.${system}.luvit;

          replaceList = from: to: l: assert builtins.elem from l; (nixpkgs.lib.remove from l) ++ [ to ];
          replaceString = from: to: s: assert nixpkgs.lib.hasInfix (builtins.unsafeDiscardStringContext from) s; builtins.replaceStrings [ from ] [ to ] s;

          luvi-patched = luvi.overrideAttrs (finalAttrs: prevAttrs: {
            buildInputs = replaceList pkgs.openssl pkgs.quictls prevAttrs.buildInputs;
            patches = [ "${self}/luvi.patch" ];
            patchPhase = null;
            postPatch = prevAttrs.patchPhase;
          });

          luviBase-patched = luviBase.overrideAttrs (finalAttrs: prevAttrs: {
            text = replaceString "${luvi}" "${luvi-patched}" prevAttrs.text;
          });

          luvit-patched = luvit.overrideAttrs (finalAttrs: prevAttrs: {
            buildInputs = replaceList luvi luvi-patched prevAttrs.buildInputs;
            buildPhase = replaceString "${luviBase}" "${luviBase-patched}" prevAttrs.buildPhase;
          });

          devShell = pkgs.mkShell {
            buildInputs = [
              lit
              luvit-patched
              pkgs.quictls
            ];
          };

          formatter = pkgs.writeShellApplication {
            name = "run-formatters";
            runtimeInputs = [
              pkgs.fd
              pkgs.nixpkgs-fmt
              pkgs.stylua
            ];
            text = ''
              fd --type=file --extension=nix --exec-batch nixpkgs-fmt --
              fd --type=file --extension=lua --exec-batch stylua --
            '';
          };

          dtls = pkgs.stdenv.mkDerivation {
            name = "dtls";
            src = self;
            phases = [ "unpackPhase" ];
            preUnpack = ''
              mkdir $out
              cd $out
            '';
          };

          default = dtls;

        in
        { inherit devShell formatter dtls default; });

    };
}
