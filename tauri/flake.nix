{
  description = "A Nix-flake-based Rust development environment with Tauri for NixOS-WSL";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1.*.tar.gz";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { self, nixpkgs, rust-overlay }:
    let
      supportedSystems = [ "x86_64-linux" ];
      forEachSupportedSystem = f: nixpkgs.lib.genAttrs supportedSystems (system: f {
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ rust-overlay.overlays.default ];
        };
      });
    in
    {
      devShells = forEachSupportedSystem ({ pkgs }: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            # Rust toolchain
            (rust-bin.stable.latest.default.override {
              extensions = [ "rust-src" ];
            })
            
            # Core dependencies
            openssl
            pkg-config
            cargo-deny
            cargo-edit
            cargo-watch
            rust-analyzer

            # Tauri requirements
            nodejs
            nodePackages.pnpm
            nodePackages.@tauri-apps/cli

            # WSL-specific GUI requirements
            webkitgtk
            libappindicator-gtk3
            librsvg
            gtk3
            dbus
            
            # Additional WSL helpers
            wslu  # For better Windows-WSL integration
          ];

          env = {
            RUST_SRC_PATH = "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";
            
            # WSL GUI integration
            DISPLAY = ":0";
            WAYLAND_DISPLAY = "wayland-0";
            XDG_RUNTIME_DIR = "/tmp/wsl-runtime";
            LIBGL_ALWAYS_INDIRECT = "1";
            
            # Tauri configuration
            TAURI_CLI_PATH = "${pkgs.nodePackages.@tauri-apps/cli}/bin/tauri";
          };

          shellHook = ''
            # Create runtime directory
            mkdir -p $XDG_RUNTIME_DIR
            chmod 700 $XDG_RUNTIME_DIR
            
            # Start D-Bus daemon if not running
            if ! pgrep dbus-daemon > /dev/null; then
              mkdir -p /var/run/dbus
              dbus-daemon --system --fork
            fi
            
            # WSL-specific path configuration
            export CARGO_HOME="$HOME/.cargo"
            export npm_config_cache="$HOME/.npm"
            echo "Make sure Windows Defender excludes your project directory for better I/O performance!"
          '';
        };
      });
    };
}