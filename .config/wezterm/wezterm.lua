local wezterm = require("wezterm")
local success, wal_colors = pcall(dofile, os.getenv("HOME") .. "/.cache/wal/colors-wez.lua")

return {
	font = wezterm.font_with_fallback({
    { family = "MartianMono NF", weight = "Regular"},
    { family = "M PLUS 1", weight = "Bold"},
  }),

	colors = success and wal_colors or nil,

	font_size = 11,
	window_close_confirmation = "NeverPrompt",
	enable_tab_bar = false,

	window_padding = {
		left = 20,
		right = 20,
		top = 20,
		bottom = 20,
	},
}
