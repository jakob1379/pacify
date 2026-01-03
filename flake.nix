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
          platformVersions = [ "36" "35" ];
          buildToolsVersions = [ "36.0.0" "35.0.0" ];
          includeEmulator = true;
          emulatorVersion = "35.3.11";
          includeSystemImages = true;
          systemImageTypes = [ "google_apis_playstore" ];
          abiVersions = [ "x86_64" ];
          includeNDK = false;
          includeSources = false;
          extraLicenses = [
            "android-googletv-license"
            "android-sdk-arm-dbt-license"
            "android-sdk-preview-license"
            "google-gdk-license"
            "intel-android-extra-license"
            "intel-android-sysimage-license"
            "mips-android-sysimage-license"
          ];
        };

        androidSdk = androidPkgs.androidsdk;
        androidSdkRoot = "${androidSdk}/libexec/android-sdk";

        # Writable Android user directory (outside Nix store)
        androidUserHome = "$HOME/.android-nix";

      in
      {
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
            # Emulator dependencies
            mesa
            libGL
            vulkan-loader
            xorg.libX11
            xorg.libXcursor
            xorg.libXrandr
            xorg.libXi
            libpulseaudio
            alsa-lib
            # Flutter web
            chromium
          ];

          ANDROID_HOME = androidSdkRoot;
          ANDROID_SDK_ROOT = androidSdkRoot;
          ANDROID_USER_HOME = androidUserHome;
          ANDROID_AVD_HOME = "${androidUserHome}/avd";
          JAVA_HOME = pkgs.jdk17.home;
          CHROME_EXECUTABLE = "${pkgs.chromium}/bin/chromium";

          # Emulator GPU acceleration
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
            pkgs.vulkan-loader
            pkgs.libGL
            pkgs.mesa
          ];

          shellHook = ''
            export PATH="${androidSdkRoot}/platform-tools:${androidSdkRoot}/emulator:${androidSdkRoot}/cmdline-tools/latest/bin:$PATH"

            # Create writable directories for AVDs and Android Studio config
            mkdir -p "${androidUserHome}/avd"
            mkdir -p "${androidUserHome}/.android"

            # Copy licenses to writable location if needed
            if [ ! -d "${androidUserHome}/licenses" ]; then
              cp -r "${androidSdkRoot}/licenses" "${androidUserHome}/" 2>/dev/null || true
            fi

            echo "Android SDK: $ANDROID_SDK_ROOT"
            echo "AVD Home: $ANDROID_AVD_HOME"
            echo ""
            echo "Available system images:"
            ${androidSdk}/bin/avdmanager list target 2>/dev/null | head -20 || true
          '';
        };
      }
    );
}
