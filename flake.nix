{
  description = "Zen Browser";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachSystem ["x86_64-linux" "aarch64-linux"] (
      system: let
        pkgs = import nixpkgs {inherit system;};
        version = "1.10b";

        # Define the correct URL and SHA256 per architecture
        downloadData =
          {
            x86_64-linux = {
              url = "https://github.com/zen-browser/desktop/releases/download/${version}/zen.linux-x86_64.tar.xz";
              sha256 = "sha256:06v8caplc3qakqc9ifyfr0zmzpg83m86kc8yy8yaln77hxvw7lbz";
            };
            aarch64-linux = {
              url = "https://github.com/zen-browser/desktop/releases/download/${version}/zen.linux-aarch64.tar.xz";
              sha256 = "sha256:1vdxszh52r2zh7fpg2jklzcmiy2hvwf20bji8vnzrasdki2x6bpx";
            };
          }
          ."${system}";

        runtimeLibs = with pkgs;
          [
            libGL
            libGLU
            libevent
            libffi
            libjpeg
            libpng
            libstartup_notification
            libvpx
            libwebp
            stdenv.cc.cc
            fontconfig
            libxkbcommon
            zlib
            freetype
            gtk3
            libxml2
            dbus
            xcb-util-cursor
            alsa-lib
            libpulseaudio
            pango
            atk
            cairo
            gdk-pixbuf
            glib
            udev
            libva
            mesa
            libnotify
            cups
            pciutils
            ffmpeg
            libglvnd
            pipewire
          ]
          ++ (with pkgs.xorg; [
            libxcb
            libX11
            libXcursor
            libXrandr
            libXi
            libXext
            libXcomposite
            libXdamage
            libXfixes
            libXScrnSaver
          ]);

        mkZen = pkgs.stdenv.mkDerivation {
          pname = "zen-browser";
          inherit version;

          # Dynamically fetch the correct binary based on system architecture
          src = builtins.fetchTarball {
            url = downloadData.url;
            sha256 = downloadData.sha256;
          };

          desktopSrc = ./.;
          phases = ["installPhase" "fixupPhase"];
          nativeBuildInputs = [pkgs.makeWrapper pkgs.copyDesktopItems pkgs.wrapGAppsHook];

          installPhase = ''
            mkdir -p $out/bin && cp -r $src/* $out/bin
            install -D $desktopSrc/zen.desktop $out/share/applications/zen.desktop
            install -D $src/browser/chrome/icons/default/default128.png $out/share/icons/hicolor/128x128/apps/zen.png
          '';

          fixupPhase = ''
            chmod 755 $out/bin/*
            for bin in zen zen-bin glxtest updater vaapitest; do
              patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/bin/$bin
              wrapProgram $out/bin/$bin --set LD_LIBRARY_PATH "${pkgs.lib.makeLibraryPath runtimeLibs}" \
                              --set MOZ_LEGACY_PROFILES 1 --set MOZ_ALLOW_DOWNGRADE 1 --set MOZ_APP_LAUNCHER zen --prefix XDG_DATA_DIRS : "$GSETTINGS_SCHEMAS_PATH"
            done
          '';

          meta.mainProgram = "zen";
        };
      in {
        packages.default = mkZen;
      }
    );
}
