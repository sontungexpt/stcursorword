local vim = vim
local api = vim.api
local fn = vim.fn
local w = vim.w
local g = vim.g
local new_cmd = api.nvim_create_user_command
local autocmd = api.nvim_create_autocmd
local hl = api.nvim_set_hl

local STCW_GROUP_NAME = "STCursorWord"
local stcw_old_line_pos = -1 -- old line where the word was found
local stcw_old_scol_pos = math.huge -- old start column position of the word found
local stcw_old_ecol_pos = -1 -- old end column position of the word found

local M = {}

local DEFAULT_OPTS = {
	max_word_length = 100,
	min_word_length = 2,
	excluded = {
		filetypes = {
			"TelescopePrompt",
		},
		buftypes = {
			-- "terminal",
			-- "nofile",
		},
		file_patterns = {
			-- "%.png$",
			-- "%.jpg$",
			-- "%.jpeg$",
			-- "%.pdf$",
			-- "%.zip$",
			-- "%.tar$",
			-- "%.tar%.gz$",
			-- "%.tar%.xz$",
			-- "%.tar%.bz2$",
			-- "%.rar$",
			-- "%.7z$",
			-- "%.mp3$",
			-- "%.mp4$",
		},
	},
	highlight = {
		underline = true,
	},
}

local matchdelete = function()
	if w.stcw_match_id ~= nil then
		fn.matchdelete(w.stcw_match_id)
		w.stcw_match_id = nil
		stcw_old_scol_pos = math.huge
		stcw_old_ecol_pos = -1
	end
end

local matchadd = function(user_opts)
	local current_pos = api.nvim_win_get_cursor(0)
	local curr_col_pos = current_pos[2]
	local curr_line_pos = current_pos[1]

	-- if cusor doesn't move out of the word, do nothing
	if
		g.stcw_enabled
		and stcw_old_line_pos == curr_line_pos
		and curr_col_pos >= stcw_old_scol_pos
		and curr_col_pos < stcw_old_ecol_pos
	then
		return
	end
	stcw_old_line_pos = curr_line_pos

	-- clear old match
	matchdelete()

	local line = api.nvim_get_current_line()

	-- Fixes vim:E976 error when cursor is on a blob
	if fn.type(line) == vim.v.t_blob then return end

	local matches = fn.matchstrpos(line:sub(1, curr_col_pos + 1), [[\w*$]])
	local word = matches[1]

	if word ~= "" then
		stcw_old_scol_pos = matches[2]
		matches = fn.matchstrpos(line, [[^\w*]], curr_col_pos + 1)
		word = word .. matches[1]
		stcw_old_ecol_pos = matches[3]

		if #word < user_opts.min_word_length or #word > user_opts.max_word_length then return end

		w.stcw_match_id =
			fn.matchadd(STCW_GROUP_NAME, [[\(\<\|\W\|\s\)\zs]] .. word .. [[\ze\(\s\|[^[:alnum:]_]\|$\)]], -1)
	end
end

local matches_file_patterns = function(file_name, file_patterns)
	for _, pattern in ipairs(file_patterns) do
		if file_name:match(pattern) then return true end
	end
	return false
end

local is_disabled = function(user_opts, bufnr)
	bufnr = bufnr or 0
	local buftype = api.nvim_buf_get_option(bufnr, "buftype")
	local filetype = api.nvim_buf_get_option(bufnr, "filetype")
	local file_name = api.nvim_buf_get_name(bufnr)

	if
		vim.tbl_contains(user_opts.excluded.buftypes, buftype)
		or vim.tbl_contains(user_opts.excluded.filetypes, filetype)
		or matches_file_patterns(file_name, user_opts.excluded.file_patterns)
	then
		return true
	end
	return false
end

local enable = function(user_opts)
	-- initial when plugin is loaded
	hl(0, STCW_GROUP_NAME, user_opts.highlight)
	local group = api.nvim_create_augroup(STCW_GROUP_NAME, { clear = true })
	local is_buf_disabled = is_disabled(user_opts)

	if not is_buf_disabled then matchadd(user_opts) end -- initial match

	-- update highlight when color scheme is changed
	autocmd({ "ColorScheme" }, {
		group = group,
		callback = function() hl(0, STCW_GROUP_NAME, user_opts.highlight) end,
	})

	local skip_cursormoved = false

	autocmd({ "BufEnter", "WinEnter" }, {
		group = group,
		callback = function()
			-- Wait for 8ms to ensure the buffer is fully loaded to avoid errors.
			-- If the buffer is not fully loaded:
			-- - The current line is 0.
			-- - The buffer type (buftype) is nil.
			-- - The file type (filetype) is nil.
			skip_cursormoved = true
			vim.defer_fn(function()
				is_buf_disabled = is_disabled(user_opts)
				if not is_buf_disabled then matchadd(user_opts) end
			end, 8)
		end,
	})

	autocmd({ "CursorMoved", "CursorMovedI" }, {
		group = group,
		callback = function()
			if skip_cursormoved then
				skip_cursormoved = false
				return
			end
			if not is_buf_disabled then matchadd(user_opts) end
		end,
	})

	autocmd({ "BufLeave", "WinLeave" }, {
		group = group,
		callback = function() matchdelete() end,
	})

	g.stcw_enabled = true
end

local disable = function()
	matchdelete()
	api.nvim_del_augroup_by_name(STCW_GROUP_NAME)
	g.stcw_enabled = false
end

local setup_command = function(user_opts)
	new_cmd("CursorwordEnable", function() enable(user_opts) end, { nargs = 0 })
	new_cmd("CursorwordDisable", function() disable() end, { nargs = 0 })
end

M.setup = function(opts)
	local user_opts = vim.tbl_deep_extend("force", DEFAULT_OPTS, opts or {})
	setup_command(user_opts)
	enable(user_opts)
end

return M
