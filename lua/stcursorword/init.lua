local api = vim.api
local fn = vim.fn
local w = vim.w
local g = vim.g
local new_cmd = api.nvim_create_user_command
local autocmd = api.nvim_create_autocmd
local hl = api.nvim_set_hl

local stcw_group_name = "STCursorword"
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
			-- "nofile",
			-- "terminal",
		},
		file_patterns = {
			"%.png$",
			"%.jpg$",
			"%.jpeg$",
			"%.pdf$",
			"%.zip$",
			"%.tar$",
			"%.tar%.gz$",
			"%.tar%.xz$",
			"%.tar%.bz2$",
			"%.rar$",
			"%.7z$",
			"%.mp3$",
			"%.mp4$",
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
	local pos = api.nvim_win_get_cursor(0)
	local col = pos[2]

	-- if cusor doesn't move out of the word, do nothing
	if
		g.stcw_enabled
		and stcw_old_line_pos == pos[1]
		and col >= stcw_old_scol_pos
		and col < stcw_old_ecol_pos
	then
		return
	end
	stcw_old_line_pos = pos[1]

	-- clear old match
	matchdelete()

	local line = api.nvim_get_current_line()

	local matches = fn.matchstrpos(line:sub(1, col + 1), [[\w*$]])
	local word = matches[1]

	if word ~= "" then
		stcw_old_scol_pos = matches[2]
		matches = fn.matchstrpos(line, [[^\w*]], col + 1)
		word = word .. matches[1]
		stcw_old_ecol_pos = matches[3]

		if #word < user_opts.min_word_length or #word > user_opts.max_word_length then return end

		w.stcw_match_id =
			fn.matchadd(stcw_group_name, [[\(\<\|\W\|\s\)\zs]] .. word .. [[\ze\(\s\|[^[:alnum:]_]\|$\)]], -1)
	end
end

local matches_file_patterns = function(file_name, file_patterns)
	for _, pattern in ipairs(file_patterns) do
		if file_name:match(pattern) then return true end
	end
	return false
end

local is_disabled = function(user_opts)
	local buftype = api.nvim_buf_get_option(0, "buftype")
	local filetype = api.nvim_buf_get_option(0, "filetype")
	local file_name = api.nvim_buf_get_name(0)
	if
		vim.tbl_contains(user_opts.excluded.buftypes, buftype)
		or vim.tbl_contains(user_opts.excluded.filetypes, filetype)
		or matches_file_patterns(file_name, user_opts.excluded.file_patterns)
	then
		return true
	end
	return false
end

local setup_autocmd = function(user_opts)
	hl(0, stcw_group_name, user_opts.highlight) -- make sure highlight option is set when the plugin is loaded or
	local group = api.nvim_create_augroup(stcw_group_name, { clear = true })

	local check_and_matchadd = function()
		w.stcw_disabled = (w.stcw_disabled == nil and is_disabled(user_opts)) and true or false
		if not w.stcw_disabled then matchadd(user_opts) end
	end

	check_and_matchadd() -- initial match when the plugin is loaded

	autocmd({ "ColorScheme" }, { -- make sure highlight is set after ColorScheme
		group = group,
		callback = function() hl(0, stcw_group_name, user_opts.highlight) end,
	})

	local skip_cursor_moved = false -- skip the first CursorMoved event after BufEnter

	autocmd({ "BufEnter" }, {
		group = group,
		callback = function()
			skip_cursor_moved = true
			check_and_matchadd()
		end,
	})

	autocmd({ "CursorMoved", "CursorMovedI" }, {
		group = group,
		callback = function()
			if skip_cursor_moved then
				skip_cursor_moved = false
				return
			end
			check_and_matchadd()
		end,
	})

	autocmd({ "BufLeave" }, {
		group = group,
		callback = function()
			matchdelete()
			w.stcw_disabled = nil
		end,
	})
	g.stcw_enabled = true
end

local setup_command = function(user_opts)
	new_cmd("CursorwordEnable", function() setup_autocmd(user_opts) end, { nargs = 0 })

	new_cmd("CursorwordDisable", function()
		matchdelete()
		api.nvim_del_augroup_by_name(stcw_group_name)
		g.stcw_enabled = false
	end, { nargs = 0 })
end

M.setup = function(opts)
	local user_opts = vim.tbl_deep_extend("force", DEFAULT_OPTS, opts or {})
	setup_command(user_opts)
	setup_autocmd(user_opts)
end

return M
