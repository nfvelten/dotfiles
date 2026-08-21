-- Change the default Omarchy look'n'feel.
-- Portado do looknfeel.conf antigo (pre-quattro), perdido na migração pro Lua.

local active_border_color = { colors = { "rgba(a67c52ee)", "rgba(d4a574ee)" }, angle = 45 }
local inactive_border_color = "rgba(595959aa)"

hl.config({
  general = {
    gaps_in = 6,
    gaps_out = 12,

    col = {
      active_border = active_border_color,
      inactive_border = inactive_border_color,
    },
  },

  decoration = {
    rounding = 8,
    active_opacity = 1.0,
    inactive_opacity = 0.85,

    blur = {
      enabled = true,
      size = 6,
      passes = 2,
      vibrancy = 0.15,
    },

    shadow = {
      enabled = true,
      range = 8,
      render_power = 4,
      color = "rgba(a67c52bb)",
      color_inactive = "rgba(00000044)",
    },
  },
})

-- https://wiki.hypr.land/Configuring/Basics/Variables/#animations
-- hl.config({
--   animations = {
--     -- Disable all animations.
--     enabled = false,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#layout
-- hl.config({
--   layout = {
--     -- Avoid overly wide single-window layouts on wide screens.
--     single_window_aspect_ratio = { 1, 1 },
--   },
-- })

-- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
-- hl.config({
--   scrolling = {
--     -- See only one column per screen instead of two.
--     column_width = 0.97,
--   },
-- })
