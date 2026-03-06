local M = {}

M.defaults = {
	-- Scoring method
	-- "recency"  - score based on how recently each line was last touched
	-- "frequency" - score based on how many times each line has been touched
	-- "frecency"  - combination of frequency and recency (default)
	method = "recency",

	-- Highlight color scale (hex strings)
	scale = {
		min = "#0f111a", -- cold (rarely/long-ago touched)
		mid = "#1a2940", -- warm
		max = "#e85d04", -- hot (frequently/recently touched)
	},

	-- Relativity: how scores are normalized
	relativity = {
		-- "file" - normalize min/max relative to lines in the current file
		-- "time" - normalize against an absolute time window
		mode = "file",
		-- For "time" mode: age in seconds at which a line is considered "cold"
		time_range = 63072000, -- 2 years
	},

	-- Number of distinct highlight levels (more = smoother gradient, more hl groups)
	levels = 16,

	-- Automatically attach to buffers on load/write
	auto_attach = false,

	-- Filetypes (and buftypes) to skip
	exclude_filetypes = {
		"help",
		"terminal",
		"NvimTree",
		"neo-tree",
		"lazy",
		"mason",
		"TelescopePrompt",
		"nofile",
		"prompt",
		"quickfix",
	},
}

function M.merge(opts)
	return vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

return M
