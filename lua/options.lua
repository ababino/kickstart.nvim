-- Enable autoread and set up auto-reloading
vim.o.autoread = true
vim.o.updatetime = 1000 -- Check every 1 second

-- Create autocommands for auto-reloading
vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter', 'CursorHold', 'CursorHoldI' }, {
  pattern = '*',
  command = "if mode() != 'c' | checktime | endif",
  desc = 'Check if we need to reload the file when it changed.',
})

-- Notification after file change
vim.api.nvim_create_autocmd('FileChangedShellPost', {
  pattern = '*',
  command = "echohl WarningMsg | echo 'File changed on disk. Buffer reloaded.' | echohl None",
  desc = 'Notification after file change.',
})

-- File copy function
local function copy_file(src, dst)
  local input = io.open(src, 'rb')
  if not input then
    return false
  end
  local output = io.open(dst, 'wb')
  if not output then
    input:close()
    return false
  end
  local content = input:read '*all'
  output:write(content)
  input:close()
  output:close()
  return true
end

-- Helper function to get date string for X days ago
local function get_date_days_ago(days)
    return os.date('%Y-%m-%d', os.time() - (86400 * days))
end

-- Function to create or open daily note
local function open_daily_note()
    local date = os.date('%Y-%m-%d')
    local dir_path = '02 Areas/Daily'
    local file_path = dir_path .. '/' .. date .. '.md'

    -- Ensure the directory exists
    vim.fn.mkdir(dir_path, 'p')

    -- Check if today's file exists
    local f = io.open(file_path, 'r')
    if f then
        f:close()
        vim.cmd('edit ' .. file_path)
        return
    end

    -- Look back up to 7 days for the most recent note
    for i = 1, 7 do
        local past_date = get_date_days_ago(i)
        local past_file_path = dir_path .. '/' .. past_date .. '.md'
        local past_file = io.open(past_file_path, 'r')
        
        if past_file then
            past_file:close()
            -- Found a previous note, copy it
            local copy_success = copy_file(past_file_path, file_path)
            vim.cmd('edit ' .. file_path)
            -- Replace the first line with today's date
            vim.api.nvim_buf_set_lines(0, 0, 1, false, { '# ' .. date })
            vim.cmd('write')
            return
        end
    end

    -- If no notes found in the last 7 days, create a new one
    vim.cmd('edit ' .. file_path)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { '# ' .. date })
    vim.cmd('write')
end

-- Keybinding to open daily note
vim.keymap.set('n', '<leader>dn', open_daily_note, { desc = 'Open Daily Note' })
