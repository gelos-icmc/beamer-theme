{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    systems.url = "github:nix-systems/default";
  };

  outputs = {
    self,
    systems,
    nixpkgs,
  }: let
    eachSystem = f:
      nixpkgs.lib.genAttrs
      (import systems)
      (system: f nixpkgs.legacyPackages.${system});
  in {
    packages = eachSystem (pkgs: rec {
      # Tex package
      default = theme;
      theme = pkgs.stdenvNoCC.mkDerivation rec {
        pname = "gelos-beamer";
        version = self.shortRev or "unstable";
        src = ./.;
        outputs = ["tex"];
        passthru = {
          tlDeps = with pkgs.texlive; [
            scheme-basic
            fancyvrb
            beamer
            xkeyval
            fira
            fontaxes
          ];
          tlType = "run";
        };
        nativeBuildInputs = [
          (pkgs.texlive.withPackages (_: passthru.tlDeps))
          (pkgs.writeShellScript "force-tex-output.sh" ''out="''${tex-}"'')
        ];
        installPhase = "install -D beamerthemegelos.sty gelos-dark.png gelos-light.png -t $tex/tex/latex/gelosbeamer";
      };

      # Texlive environment containing the theme
      texlive-env = pkgs.texlive.withPackages (_: default.tlDeps ++ [default]);

      # A function to easen usage
      mkGelosSlides = {
        pname ? "slides",
        version ? "unstable",
        src,
        ignore ? ["README.md"],
        texlive ? texlive-env,
        pandoc ? pkgs.pandoc,
        ...
      }@args:
      pkgs.stdenvNoCC.mkDerivation {
        inherit pname version src;
        nativeBuildInputs = [pandoc texlive];
        buildPhase = ''
          rm -f ${builtins.concatStringsSep " " ignore}
          pandoc -t beamer -V theme=gelos *.md -o ${pname}.pdf
        '';
        installPhase = "install -D ${pname}.pdf -t $out";
      } // args;

      # A sample pdf using the theme
      sample = mkGelosSlides {
        pname = "sample";
        src = ./.;
      };
    });
    formatter = eachSystem (pkgs: pkgs.alejandra);
  };
}
