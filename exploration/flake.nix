{
  description = "RootPainter development shell providing Qt system dependencies";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        lib = pkgs.lib;
        runtimeLibs = with pkgs; [
          libGL
          libglvnd
          glib
          fontconfig
          freetype
          dbus
          libxkbcommon
          wayland
        ] ++ (with xorg; [
          libX11
          libXext
          libXfixes
          libXrender
          libXcursor
          libXi
          libXrandr
          libXinerama
          libSM
          libICE
          libxcb
          xcbutil
          xcbutilrenderutil
          xcbutilkeysyms
          xcbutilimage
          xcbutilwm
          xcbutilcursor
        ]);
      in {
        devShells.default = pkgs.mkShell {
          packages = runtimeLibs ++ (with pkgs; [ uv pkg-config ]);
          LD_LIBRARY_PATH = lib.makeLibraryPath runtimeLibs;
        };
      }
    );
}
