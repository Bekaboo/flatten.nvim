local M = {}

local function send_files(host, files, stdin)
	if #files < 1 and #stdin < 1 then return end

	local call = string.format([[
		return require('flatten.core').edit_files(
			%s,   -- `args` passed into nested instance.
			'%s', -- guest default socket.
			'%s', -- guest global cwd.
			%s    -- stdin lines or {}.
		)]],
		vim.inspect(files),
		vim.v.servername,
		vim.fn.getcwd(),
		vim.inspect(stdin)
	)

	local block = vim.fn.rpcrequest(host, "nvim_exec_lua", call, {})
	if not block then
		vim.cmd('qa!')
	end
	vim.fn.chanclose(host)
	while true do
		vim.cmd("sleep 1")
	end
end

M.init = function(host_pipe)
	-- Connect to host process
	local host = vim.fn.sockconnect("pipe", host_pipe, { rpc = true })
	-- Exit on connection error
	if host == 0 then vim.cmd("qa!") end

	-- Get new files
	local files = vim.fn.argv()
	local nfiles = #files

	vim.api.nvim_create_autocmd("StdinReadPost", {
		pattern = '*',
		callback = function()
			local readlines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
			send_files(host, files, readlines)
		end
	})

	-- No arguments, user is probably opening a nested session intentionally
	-- Or only piping input from stdin
	vim.api.nvim_create_autocmd("BufEnter", {
		pattern = '*',
		callback = function()
			if nfiles < 1 then
				vim.cmd('qa!')
			end

			send_files(host, files, {})
		end
	})
end

return M
