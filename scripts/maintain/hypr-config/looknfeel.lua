hl.config({
  general = {
    gaps_in = 3,
    gaps_out = 4,
    border_size = 5,
  },
})

hl.config({
  decoration = {
    rounding = 8,
    dim_inactive = true,
    dim_strength = 0.15,
  },
})

-- Workspace changes slide instead of cutting (Omarchy turns this off), so a
-- jump to another workspace is visible.
hl.animation({ leaf = "workspaces", enabled = true, speed = 3, bezier = "easeOutQuint", style = "slide" })
