{
  description = "Android Studio + Android SDK (emulator + system images) + FHS env for Flutter/Gradle";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            android_sdk.accept_license = true;
          };
        };

        androidStudio = pkgs.androidStudioPackages.stable;

        androidPkgs = pkgs.androidenv.composeAndroidPackages {
          platformVersions = [ "36" ];
          buildToolsVersions = [ "28.0.3" ];
          includeEmulator = false;
          includeSystemImages = false;
          includeNDK = false;
        };

        androidSdk = androidPkgs.androidsdk;
        androidSdkRoot = "${androidSdk}/libexec/android-sdk";

      in
      {
        packages = {};
        apps = {};

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            jdk17
            gradle
            flutter
            git
            unzip
            zip
            androidStudio
            androidSdk
            mesa
            libGL
            chromium
            virtualgl
          ];

          ANDROID_HOME = androidSdkRoot;
          JAVA_HOME = pkgs.jdk17.home;
          ANDROID_SDK_ROOT = androidSdkRoot;
          CHROME_EXECUTABLE = "${pkgs.chromium}/bin/chromium";
          shellHook = ''
            export PATH="$ANDROID_SDK_ROOT/platform-tools:$PATH"
            if [ -d "$ANDROID_SDK_ROOT/cmdline-tools" ]; then
              export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$PATH"
            fi

            # Accept Android licenses if not already accepted
            if [ ! -f "$ANDROID_SDK_ROOT/licenses/android-sdk-license" ]; then
              yes | flutter doctor --android-licenses > /dev/null 2>&1 || true
            fi
          '';
        };
      }
    );
}
