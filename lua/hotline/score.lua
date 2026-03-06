local M = {}

-- Exponential decay: half-life of 7 days.
-- A line touched today scores 1.0; a line touched 7 days ago scores ~0.5.
local DECAY_LAMBDA = math.log(2) / (7 * 86400)

local function recency_raw(timestamp, now)
  local age = math.max(0, now - (timestamp or 0))
  return math.exp(-DECAY_LAMBDA * age)
end

local function normalize_file(scores)
  local min_v, max_v = math.huge, -math.huge
  for _, v in pairs(scores) do
    if v < min_v then min_v = v end
    if v > max_v then max_v = v end
  end
  local range = max_v - min_v
  local out = {}
  for k, v in pairs(scores) do
    out[k] = range > 0 and (v - min_v) / range or 1.0
  end
  return out
end

-- Compute a normalized score in [0.0, 1.0] for each line.
--
-- blame:      { [line_num] = { hash, timestamp } }  (from git.blame)
-- touches:    { [line_num] = touch_score }          (from git.parse_frequency), or nil
-- method:     "recency" | "frequency" | "frecency"
-- relativity: { mode = "file"|"time", time_range = number }
--
-- Returns { [line_num] = normalized_score }
function M.compute(blame, touches, method, relativity)
  local now = os.time()
  local scores = {}

  if method == "recency" then
    if relativity.mode == "time" then
      -- Absolute time window: score = 1 at now, 0 at (now - time_range)
      local range = relativity.time_range or 63072000
      for line, data in pairs(blame) do
        local age = math.max(0, now - (data.timestamp or 0))
        scores[line] = math.max(0.0, 1.0 - age / range)
      end
      return scores
    else
      -- File-relative: normalize decay scores across lines in this file
      for line, data in pairs(blame) do
        scores[line] = recency_raw(data.timestamp, now)
      end
      return normalize_file(scores)
    end

  elseif method == "frequency" then
    -- Touch counts normalized relative to max in this file.
    -- Falls back to recency if frequency data is unavailable.
    if touches then
      for line, _ in pairs(blame) do
        scores[line] = touches[line] or 0
      end
      return normalize_file(scores)
    else
      for line, data in pairs(blame) do
        scores[line] = recency_raw(data.timestamp, now)
      end
      return normalize_file(scores)
    end

  else -- frecency: average of normalized recency and normalized frequency
    local r_scores, f_scores = {}, {}

    for line, data in pairs(blame) do
      if relativity.mode == "time" then
        local range = relativity.time_range or 63072000
        local age = math.max(0, now - (data.timestamp or 0))
        r_scores[line] = math.max(0.0, 1.0 - age / range)
      else
        r_scores[line] = recency_raw(data.timestamp, now)
      end
      f_scores[line] = (touches and touches[line]) or 0
    end

    local r_norm = relativity.mode == "time" and r_scores or normalize_file(r_scores)
    local f_norm = normalize_file(f_scores)

    for line, _ in pairs(blame) do
      scores[line] = ((r_norm[line] or 0) + (f_norm[line] or 0)) / 2
    end
    return scores
  end
end

return M
