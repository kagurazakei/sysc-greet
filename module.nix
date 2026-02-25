{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.services.sysc-greet;
  niripkg = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri;
  package = pkgs.callPackage ./default.nix { };
in
with lib;
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
    compositorPackage = mkOption {
      type = types.package;
      default =
        if config.services.sysc-greet.compositor == "niri" then
          inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri
        else if config.services.sysc-greet.compositor == "hyprland" then
          pkgs.hyprland
        else
          pkgs.sway;

      description = "Compositor package to use";
    };
    settings = mkOption {
      type = types.attrs;
      default = { };
      description = "Additional greetd settings";
    };
  };

  config = mkIf cfg.enable {

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
        terminal.vt = 1;

        default_session = {
          command =
            if cfg.compositor == "niri" then
              "${niripkg}/bin/niri -c /etc/greetd/niri-greeter-config.kdl"
            else if cfg.compositor == "hyprland" then
              "${pkgs.hyprland}/bin/start-hyprland -- -c /etc/greetd/hyprland-greeter-config.conf"
            else
              "${pkgs.sway}/bin/sway -c /etc/greetd/sway-greeter-config";

          user = "greeter";
        };
      }
      // lib.optionalAttrs (cfg.settings ? initial_session) {
        initial_session = cfg.settings.initial_session;
      };
    };

    environment.systemPackages = [
      package
      pkgs.kitty
      pkgs.swww
      cfg.compositorPackage
    ]
    ++ (
      if cfg.compositor == "niri" then
        [ niripkg ]
      else if cfg.compositor == "hyprland" then
        [ pkgs.hyprland ]
      else
        [ pkgs.sway ]
    );

    environment.etc = {
      "greetd/kitty.conf".source = "${package}/etc/greetd/kitty.conf";

      "greetd/niri-greeter-config.kdl".source = "${package}/etc/greetd/niri-greeter-config.kdl";

      "greetd/hyprland-greeter-config.conf".source = "${package}/etc/greetd/hyprland-greeter-config.conf";

      "greetd/sway-greeter-config".source = "${package}/etc/greetd/sway-greeter-config";

      "polkit-1/rules.d/85-greeter.rules".source = "${package}/etc/polkit-1/rules.d/85-greeter.rules";
    };

    systemd.tmpfiles.rules = [
      "d /var/cache/sysc-greet 0755 greeter greeter -"
      "L+ /usr/share/sysc-greet - - - - ${package}/share/sysc-greet"
    ];

    security.polkit.enable = true;
  };
}
