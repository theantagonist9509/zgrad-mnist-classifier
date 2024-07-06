{
  outputs = { nixpkgs, ... }:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in
  {
    devShells.${system}.default = pkgs.mkShell {
      packages = with pkgs;[ libGL xorg.libX11 ];
      shellHook = ''
        export PS1="\n\[\033[1;36m\][\[\e]0;raylib: \w\a\]raylib:\w]\$\[\033[0m\] "
        export LD_LIBRARY_PATH=${pkgs.libGL}/lib:${pkgs.xorg.libX11}/lib:$LD_LIBRARY_PATH
      '';
    };
  };
}
