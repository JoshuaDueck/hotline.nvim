local M = {}

local function hex_to_rgb(hex)
  hex = hex:gsub("^#", "")
  return {
    r = tonumber(hex:sub(1, 2), 16),
    g = tonumber(hex:sub(3, 4), 16),
    b = tonumber(hex:sub(5, 6), 16),
  }
end

local function rgb_to_hex(r, g, b)
  return string.format(
    "#%02x%02x%02x",
    math.max(0, math.min(255, math.floor(r + 0.5))),
    math.max(0, math.min(255, math.floor(g + 0.5))),
    math.max(0, math.min(255, math.floor(b + 0.5)))
  )
end

local function lerp_rgb(a, b, t)
  return {
    r = a.r + (b.r - a.r) * t,
    g = a.g + (b.g - a.g) * t,
    b = a.b + (b.b - a.b) * t,
  }
end

-- Interpolate across min -> mid -> max color scale.
-- t = 0.0 → min, t = 0.5 → mid, t = 1.0 → max
function M.interpolate(t, scale)
  local min_rgb = hex_to_rgb(scale.min)
  local mid_rgb = hex_to_rgb(scale.mid)
  local max_rgb = hex_to_rgb(scale.max)

  local rgb
  if t <= 0.5 then
    rgb = lerp_rgb(min_rgb, mid_rgb, t * 2)
  else
    rgb = lerp_rgb(mid_rgb, max_rgb, (t - 0.5) * 2)
  end

  return rgb_to_hex(rgb.r, rgb.g, rgb.b)
end

-- Create (or update) highlight groups HotlineLevel0..HotlineLevel(n-1).
-- Returns a list of group names indexed 1..levels.
function M.setup_highlights(scale, levels)
  local groups = {}
  for i = 0, levels - 1 do
    local t = levels > 1 and (i / (levels - 1)) or 1.0
    local bg = M.interpolate(t, scale)
    local name = string.format("HotlineLevel%d", i)
    vim.api.nvim_set_hl(0, name, { bg = bg })
    groups[i + 1] = name
  end
  return groups
end

-- Map a normalized score [0, 1] to the closest highlight group name.
function M.score_to_group(score, groups)
  local levels = #groups
  local idx = math.floor(score * (levels - 1) + 0.5) + 1
  idx = math.max(1, math.min(levels, idx))
  return groups[idx]
end

return M
