{
  description = "Graphical console greeter for greetd with ASCII art and themes";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages.default = pkgs.buildGoModule rec {
          pname = "sysc-greet";
          version = "1.0.7";

          src = ./.;

          vendorHash = "sha256-dNkp1/ms1dO6sWNK9qYVq9VGWuFbyMlqdAn+D8vpZ8w=";

          ldflags = [
            "-X main.Version=${version}"
            "-X main.GitCommit=${self.rev or "dev"}"
            "-X main.BuildDate=1970-01-01"
            "-X main.dataDir=${placeholder "out"}/share/sysc-greet"
          ];
          subPackages = [ "cmd/sysc-greet" ];
          buildVcsInfo = false;
          postInstall = ''
                        mkdir -p $out/share/sysc-greet/ascii_configs
                        cp -r ascii_configs/* $out/share/sysc-greet/ascii_configs/
                        mkdir -p $out/share/sysc-greet/fonts
                        cp -r fonts/* $out/share/sysc-greet/fonts/
                        mkdir -p $out/share/sysc-greet/wallpapers
                        cp -r wallpapers/* $out/share/sysc-greet/wallpapers/
                        mkdir -p $out/share/sysc-greet/Assets
                        cp assets/logo.png $out/share/sysc-greet/Assets/
                        cp assets/showcase.gif $out/share/sysc-greet/Assets/
                        mkdir -p $out/etc/greetd
                        cp config/kitty-greeter.conf $out/etc/greetd/kitty.conf
                        cp config/niri-greeter-config.kdl $out/etc/greetd/
                        cp config/hyprland-greeter-config.conf $out/etc/greetd/
                        cp config/hyprland-greeter-config.lua $out/etc/greetd/
                        cp config/sway-greeter-config $out/etc/greetd/
                        substituteInPlace $out/etc/greetd/niri-greeter-config.kdl \
                          --replace '/usr/local/bin/sysc-greet' "$out/bin/sysc-greet" \
                          --replace 'awww-daemon' "${pkgs.awww}/bin/awww-daemon" \
                          --replace 'kitty ' "${pkgs.kitty}/bin/kitty " \
                          --replace 'niri msg' "${pkgs.niri}/bin/niri msg"
                        
                        substituteInPlace $out/etc/greetd/hyprland-greeter-config.lua \
                          --replace '/usr/local/bin/sysc-greet' "$out/bin/sysc-greet" \
                          --replace 'awww-daemon' "${pkgs.awww}/bin/awww-daemon" \
                          --replace 'kitty ' "${pkgs.kitty}/bin/kitty " \
                          --replace 'hyprctl ' "${pkgs.hyprland}/bin/hyprctl "
                        
                        substituteInPlace $out/etc/greetd/sway-greeter-config \
                          --replace '/usr/local/bin/sysc-greet' "$out/bin/sysc-greet" \
                          --replace 'awww-daemon' "${pkgs.awww}/bin/awww-daemon" \
                          --replace 'kitty ' "${pkgs.kitty}/bin/kitty " \
                          --replace 'swaymsg ' "${pkgs.sway}/bin/swaymsg "
                        mkdir -p $out/etc/polkit-1/rules.d
                        cat > $out/etc/polkit-1/rules.d/85-greeter.rules <<'EOF'
            polkit.addRule(function(action, subject) {
                if ((action.id == "org.freedesktop.login1.power-off" ||
                     action.id == "org.freedesktop.login1.power-off-multiple-sessions" ||
                     action.id == "org.freedesktop.login1.reboot" ||
                     action.id == "org.freedesktop.login1.reboot-multiple-sessions") &&
                    subject.user == "greeter") {
                    return polkit.Result.YES;
                }
            });
            EOF
                        mkdir -p $out/var/cache/sysc-greet
          '';

          meta = with pkgs.lib; {
            description = "Graphical console greeter for greetd with ASCII art and themes";
            homepage = "https://github.com/Nomadcxx/sysc-greet";
            license = licenses.gpl3Only;
            maintainers = [ Nomadcxx ];
            platforms = platforms.linux;
            mainProgram = "sysc-greet";
          };
        };

        # Development shell
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            go_1_25
            gnumake
            git
          ];

          shellHook = ''
            echo "sysc-greet development environment"
            echo "Run 'make build' to build the greeter"
            echo "Run 'make test' to test in test mode"
          '';
        };
      }
    )
    // {
      # NixOS module
      nixosModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        with lib;
        let
          cfg = config.services.sysc-greet;
          package = self.packages.${pkgs.stdenv.hostPlatform.system}.default;

          # Get the compositor package based on user choice
          compositorPkg =
            if cfg.compositor == "niri" then
              cfg.niriPackage
            else if cfg.compositor == "hyprland" then
              cfg.hyprlandPackage
            else if cfg.compositor == "sway" then
              cfg.swayPackage
            else
              throw "Unknown compositor: ${cfg.compositor}";
        in
        {
          options.services.sysc-greet = {
            enable = mkEnableOption "sysc-greet greeter for greetd";

            compositor = mkOption {
              type = types.enum [
                "niri"
                "hyprland"
                "sway"
              ];
              default = "niri";
              description = "Wayland compositor to use with sysc-greet";
            };

            # New compositor package options
            niriPackage = mkOption {
              type = types.package;
              default = pkgs.niri;
              defaultText = literalExpression "pkgs.niri";
              description = "niri package to use";
            };

            hyprlandPackage = mkOption {
              type = types.package;
              default = pkgs.hyprland;
              defaultText = literalExpression "pkgs.hyprland";
              description = "hyprland package to use";
            };

            swayPackage = mkOption {
              type = types.package;
              default = pkgs.sway;
              defaultText = literalExpression "pkgs.sway";
              description = "sway package to use";
            };

            settings = mkOption {
              type = types.attrs;
              default = { };
              description = "Additional greetd settings";
            };
          };

          config = mkIf cfg.enable {
            # Create greeter user
            users.users.greeter = {
              isSystemUser = true;
              group = "greeter";
              home = "/var/lib/greeter";
              createHome = true;
            };

            users.groups.greeter = { };
            environment.pathsToLink = [ "/share/wayland-sessions" ];
            services.greetd = {
              enable = true;
              settings = {
                terminal = {
                  vt = 1;
                };
                default_session = {
                  command =
                    if cfg.compositor == "niri" then
                      "${compositorPkg}/bin/niri -c /etc/greetd/niri-greeter-config.kdl"
                    else if cfg.compositor == "hyprland" then
                      "${compositorPkg}/bin/start-hyprland -- --config /etc/greetd/hyprland-greeter-config.lua"
                    else
                      "${compositorPkg}/bin/sway -c /etc/greetd/sway-greeter-config";
                  user = "greeter";
                };
              }
              // lib.optionalAttrs (cfg.settings ? initial_session) {
                initial_session = cfg.settings.initial_session;
              };
            };

            # Install sysc-greet and compositor-specific dependencies
            environment.systemPackages = with pkgs; [
              package
              kitty
              awww
              compositorPkg
            ];

            environment.etc = {
              "greetd/kitty.conf".source = "${package}/etc/greetd/kitty.conf";
              "greetd/niri-greeter-config.kdl".source = "${package}/etc/greetd/niri-greeter-config.kdl";
              "greetd/hyprland-greeter-config.conf".source = "${package}/etc/greetd/hyprland-greeter-config.lua";
              "greetd/sway-greeter-config".source = "${package}/etc/greetd/sway-greeter-config";
              "polkit-1/rules.d/85-greeter.rules".source = "${package}/etc/polkit-1/rules.d/85-greeter.rules";
            };
            systemd.tmpfiles.rules = [
              "d /var/cache/sysc-greet 0755 greeter greeter -"
              "L+ /usr/share/sysc-greet - - - - ${package}/share/sysc-greet"
            ];
            security.polkit.enable = true;
          };
        };
    };
}
