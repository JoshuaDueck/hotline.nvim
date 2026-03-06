local M = {}

local function git_run(args, cwd)
  local result = vim.system(args, { cwd = cwd, text = true }):wait()
  if result.code ~= 0 then
    return nil
  end
  return result.stdout
end

-- Returns { [line_num] = { hash = string, timestamp = number } }
-- line_num is 1-indexed. Runs synchronously (fast, single file).
function M.blame(filepath)
  local cwd = vim.fn.fnamemodify(filepath, ":h")
  local out = git_run({ "git", "blame", "--porcelain", "--", filepath }, cwd)
  if not out then
    return nil
  end

  local commits = {} -- hash -> timestamp (number)
  local lines = {}   -- [line_num] -> { hash, timestamp }
  local cur_hash, cur_line

  -- git blame --porcelain format:
  --   <40-char-hash> <orig_line> <final_line> <num_lines>
  --   author <name>
  --   author-time <unix_timestamp>
  --   ... (more fields) ...
  --   filename <file>
  --   \t<line content>
  -- Subsequent occurrences of the same commit omit the metadata fields.
  for raw in (out .. "\n"):gmatch("([^\n]*)\n") do
    -- Commit header: 40 hex chars followed by line numbers
    local hash, final = raw:match(
      "^(%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x)"
        .. " %d+ (%d+)"
    )
    if hash then
      cur_hash = hash
      cur_line = tonumber(final)
      commits[hash] = commits[hash] or 0
    elseif cur_hash then
      local ts = raw:match("^author%-time (%d+)")
      if ts then
        commits[cur_hash] = tonumber(ts)
      elseif raw:sub(1, 1) == "\t" then
        -- Line content: record and reset current commit context
        lines[cur_line] = { hash = cur_hash, timestamp = commits[cur_hash] }
        cur_hash, cur_line = nil, nil
      end
    end
  end

  return lines
end

-- Parse the stdout of:
--   git log --follow -p --unified=0 --reverse --diff-filter=AM
--           --format="COMMIT %H %at" -- <file>
-- Returns { [line_num] = touch_score } (1-indexed array, approximate).
--
-- Algorithm: simulate file evolution from oldest to newest commit.
-- Each inserted line starts with touch_score = 1. When lines are modified
-- (replaced), the new lines inherit the average of the replaced lines' scores
-- plus 1. This approximates "how many times has this logical position been
-- touched throughout the file's history."
function M.parse_frequency(stdout)
  local touches = {} -- [i] = cumulative touch score for line i
  local in_diff = false

  for raw in (stdout .. "\n"):gmatch("([^\n]*)\n") do
    -- Commit separator
    if raw:match("^COMMIT %x+ %d+$") then
      in_diff = false

    -- Diff section start
    elseif raw:match("^diff %-%-git ") then
      in_diff = true

    elseif in_diff then
      -- Hunk header: @@ -old_start[,old_count] +new_start[,new_count] @@
      -- When a count is omitted, it defaults to 1.
      local os_, oc_, ns_, nc_ = raw:match("^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@")
      if os_ then
        local old_count = tonumber(oc_ ~= "" and oc_ or "1")
        local new_start = tonumber(ns_)
        local new_count = tonumber(nc_ ~= "" and nc_ or "1")

        -- Use new_start for both removal and insertion positions.
        -- This works because new_start already accounts for all line-count
        -- changes from previous hunks in this commit.

        -- Compute average score of lines being replaced (for inheritance)
        local old_sum = 0
        for i = new_start, new_start + old_count - 1 do
          old_sum = old_sum + (touches[i] or 0)
        end
        local inherited = old_count > 0 and (old_sum / old_count) or 0

        -- Remove replaced lines
        for _ = 1, old_count do
          table.remove(touches, new_start)
        end

        -- Insert new lines carrying inherited history + 1 touch
        for i = 0, new_count - 1 do
          table.insert(touches, new_start + i, inherited + 1)
        end
      end
    end
  end

  return touches
end

return M
