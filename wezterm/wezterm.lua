local wezterm = require("wezterm")
local config = wezterm.config_builder()

config.color_scheme = "GitHub Dark Default"
config.initial_cols = 120
config.initial_rows = 28

config.font_size = 10
config.font = wezterm.font_with_fallback({
	{
		family = "MonaspiceAr Nerd Font Mono",
		harfbuzz_features = { "ss01=1", "ss02=1", "ss03=1" },
	},
	"Noto Sans CJK JP",
})

-- config.window_decorations = "RESIZE"
config.window_background_opacity = 0.85
config.use_fancy_tab_bar = false
config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true
config.tab_bar_at_bottom = true
config.text_background_opacity = 1.0

local act = wezterm.action

config.keys = {
	{
		key = ",",
		mods = "CMD",
		action = act.SpawnCommandInNewTab({
			cwd = os.getenv("WEZTERM_CONFIG_DIR"),
			args = {
				"nvim",
				os.getenv("WEZTERM_CONFIG_FILE"),
			},
		}),
	},
	{
		key = "LeftArrow",
		mods = "CTRL",
		action = act.ActivateTabRelative(-1),
	},
	{
		key = "RightArrow",
		mods = "CTRL",
		action = act.ActivateTabRelative(1),
	},
}

return config
