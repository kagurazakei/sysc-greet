hl.config({
	general = {
		gaps_in = 0,
		gaps_out = 0,
		border_size = 0,
	},
	decoration = {
		rounding = 0,
		blur = {
			enabled = false,
		},
	},

	animations = {
		enabled = false,
	},

	misc = {
		disable_hyprland_logo = true,
		disable_splash_rendering = true,
		background_color = "#11121D",
		disable_watchdog_warning = true,
	},

	ecosystem = {
		no_update_news = true,
		no_donation_nag = true,
	},

	input = {
		kb_layout = "us",
		repeat_delay = 400,
		repeat_rate = 40,
		touchpad = {
			tap_to_click = true,
		},
	},
})

hl.window_rule({
	match = {
		class = "^(kitty)$",
	},
	fullscreen = true,
})

hl.window_rule({
	match = {
		class = "^(kitty)$",
	},
	opacity = "1.0 override 1.0 override 1.0 override",
})

hl.layer_rule({
	match = {
		namespace = "wallpaper",
	},
	blur = true,
})

hl.on("hyprland.start", function()
	hl.exec_cmd(
		"gslapper -I /tmp/sysc-greet-wallpaper.sock -o \"fill\" '*' /usr/share/sysc-greet/wallpapers/sysc-greet-default.png"
	)
	hl.exec_cmd(
		"XDG_CACHE_HOME=/tmp/greeter-cache HOME=/var/lib/greeter kitty --start-as=fullscreen --config=/etc/greetd/kitty.conf /usr/local/bin/sysc-greet && hyprctl dispatch exit"
	)
end)
