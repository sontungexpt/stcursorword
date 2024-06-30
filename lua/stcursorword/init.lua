local vim = vim
local w, fn, api = vim.w, vim.fn, vim.api
local hl, autocmd, get_cursor, get_line, matchstrpos, matchadd =
	api.nvim_set_hl,
	api.nvim_create_autocmd,
	api.nvim_win_get_cursor,
	api.nvim_get_current_line,
	fn.matchstrpos,
	fn.matchadd

local PLUG_NAME = "stcursorword"
local enabled = false
local prev_line = -1 -- The previous line number where the cursor was found
local prev_start_column = math.huge -- The previous start column position of the word found
local prev_end_column = -1 -- The previous end column position of the word found

local M = {}

local default_configs = {
	max_word_length = 100,
	min_word_length = 2,
	excluded = {
		filetypes = {},
		buftypes = {
			"prompt",
			-- "terminal",
			-- "nofile",
		},
		patterns = {
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
	if w.stcursorword ~= nil then
		fn.matchdelete(w.stcursorword)
		w.stcursorword = nil
		prev_start_column = math.huge
		prev_end_column = -1
	end
end

local highlight_same = function(configs)
	local cursor_pos = get_cursor(0)
	local cursor_column = cursor_pos[2]
	local cursor_line = cursor_pos[1]

	-- if cusor doesn't move out of the word, do nothing
	if
		enabled
		and prev_line == cursor_line
		and cursor_column >= prev_start_column
		and cursor_column < prev_end_column
	then
		return
	end
	prev_line = cursor_line

	-- clear old match
	matchdelete()

	local line = get_line()

	-- Fixes vim:E976 error when cursor is on a blob
	if fn.type(line) == vim.v.t_blob then return end

	local matches = matchstrpos(line:sub(1, cursor_column + 1), [[\w*$]])
	local word = matches[1] -- left part of the word

	if word ~= "" then
		matches = matchstrpos(line, [[^\w*]], cursor_column + 1)
		word = word .. matches[1] -- combine with right part of the word
		prev_start_column = matches[2]
		prev_end_column = matches[3]

		if #word < configs.min_word_length or #word > configs.max_word_length then return end

		w.stcursorword =
			matchadd(PLUG_NAME, [[\(\<\|\W\|\s\)\zs]] .. word .. [[\ze\(\s\|[^[:alnum:]_]\|$\)]], -1)
	end
end

local arr_contains = function(tbl, value)
	for _, v in ipairs(tbl) do
		if v == value then return true end
	end
	return false
end

local matches_file_patterns = function(file_name, file_patterns)
	for _, pattern in ipairs(file_patterns) do
		if file_name:match(pattern) then return true end
	end
	return false
end

local is_disabled = function(excluded, bufnr)
	return arr_contains(excluded.buftypes, api.nvim_get_option_value("buftype", { buf = bufnr or 0 }))
		or arr_contains(excluded.filetypes, api.nvim_get_option_value("filetype", { buf = bufnr or 0 }))
		or matches_file_patterns(api.nvim_buf_get_name(bufnr or 0), excluded.patterns)
end

local enable = function(configs)
	-- initial when plugin is loaded
	hl(0, PLUG_NAME, configs.highlight)
	local group = api.nvim_create_augroup(PLUG_NAME, { clear = true })

	local disabled_buffer = is_disabled(configs.excluded, 0)
	if not disabled_buffer then highlight_same(configs) end -- initial match

	autocmd("ColorScheme", {
		group = group,
		callback = function() hl(0, PLUG_NAME, configs.highlight) end,
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
				disabled_buffer = is_disabled(configs.excluded, 0)
				if not disabled_buffer then highlight_same(configs) end
			end, 8)
		end,
	})

	autocmd({ "CursorMoved", "CursorMovedI" }, {
		group = group,
		callback = function()
			if skip_cursormoved then
				skip_cursormoved = false
			elseif not disabled_buffer then
				highlight_same(configs)
			end
		end,
	})

	autocmd({ "BufLeave", "WinLeave" }, {
		group = group,
		callback = matchdelete,
	})

	enabled = true
end

local disable = function()
	matchdelete()
	api.nvim_del_augroup_by_name(PLUG_NAME)
	enabled = false
end

local toggle = function(configs)
	if enabled then
		disable()
	else
		enable(configs)
	end
end

local setup_command = function(configs)
	api.nvim_create_user_command("CursorwordToggle", function() toggle(configs) end, { nargs = 0 })
	api.nvim_create_user_command("CursorwordEnable", function() enable(configs) end, { nargs = 0 })
	api.nvim_create_user_command("CursorwordDisable", disable, { nargs = 0 })
end

local function merge_config(default_opts, user_opts)
	local default_options_type = type(default_opts)

	if default_options_type == type(user_opts) then
		if default_options_type == "table" and default_opts[1] == nil then
			for k, v in pairs(user_opts) do
				default_opts[k] = merge_config(default_opts[k], v)
			end
		else
			default_opts = user_opts
		end
	elseif default_opts == nil then
		default_opts = user_opts
	end
	return default_opts
end

M.setup = function(user_opts)
	local opts = merge_config(default_configs, user_opts)
	setup_command(opts)
	enable(opts)
end

return M
