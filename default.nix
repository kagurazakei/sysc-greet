{
  lib,
  buildGoModule,
  swww,
  kitty,
  niri,
  hyprland,
  sway,
}:

buildGoModule rec {
  pname = "sysc-greet";
  version = "1.0.7";

  src = ./.;

  vendorHash = "sha256-dNkp1/ms1dO6sWNK9qYVq9VGWuFbyMlqdAn+D8vpZ8w=";

  ldflags = [
    "-X main.Version=${version}"
    "-X main.GitCommit=dev"
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
        cp config/sway-greeter-config $out/etc/greetd/

        substituteInPlace $out/etc/greetd/niri-greeter-config.kdl \
          --replace '/usr/local/bin/sysc-greet' "$out/bin/sysc-greet" \
          --replace 'swww-daemon' "${swww}/bin/swww-daemon" \
          --replace 'kitty ' "${kitty}/bin/kitty " \
          --replace 'niri msg' "${niri}/bin/niri msg"

        substituteInPlace $out/etc/greetd/hyprland-greeter-config.conf \
          --replace '/usr/local/bin/sysc-greet' "$out/bin/sysc-greet" \
          --replace 'swww-daemon' "${swww}/bin/swww-daemon" \
          --replace 'kitty ' "${kitty}/bin/kitty " \
          --replace 'hyprctl ' "${hyprland}/bin/hyprctl "

        substituteInPlace $out/etc/greetd/sway-greeter-config \
          --replace '/usr/local/bin/sysc-greet' "$out/bin/sysc-greet" \
          --replace 'swww-daemon' "${swww}/bin/swww-daemon" \
          --replace 'kitty ' "${kitty}/bin/kitty " \
          --replace 'swaymsg ' "${sway}/bin/swaymsg "

        mkdir -p $out/etc/polkit-1/rules.d
        cat > $out/etc/polkit-1/rules.d/85-greeter.rules <<'EOF'
    polkit.addRule(function(action, subject) {
        if ((action.id == "org.freedesktop.login1.power-off" ||
             action.id == "org.freedesktop.login1.reboot") &&
            subject.user == "greeter") {
            return polkit.Result.YES;
        }
    });
    EOF

        mkdir -p $out/var/cache/sysc-greet
  '';

  meta = {
    description = "Graphical console greeter for greetd with ASCII art and themes";
    homepage = "https://github.com/Nomadcxx/sysc-greet";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "sysc-greet";
  };
}
