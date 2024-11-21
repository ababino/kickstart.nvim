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

-- Function to create or open daily note
local function open_daily_note()
  local date = os.date '%Y-%m-%d'
  local yesterday = os.date('%Y-%m-%d', os.time() - 86400) -- 86400 seconds in a day
  local dir_path = '02 Areas/Daily'
  local file_path = dir_path .. '/' .. date .. '.md'
  local yesterday_path = dir_path .. '/' .. yesterday .. '.md'

  -- Ensure the directory exists
  vim.fn.mkdir(dir_path, 'p')

  -- Check if today's file exists
  local f = io.open(file_path, 'r')
  if f then
    f:close()
    vim.cmd('edit ' .. file_path)
  else
    -- Check if yesterday's file exists
    local y = io.open(yesterday_path, 'r')
    if y then
      y:close()
      -- Copy yesterday's file
      local copy_success = copy_file(yesterday_path, file_path)
      -- Open the new file
      vim.cmd('edit ' .. file_path)
      -- Replace the first line with today's date
      vim.api.nvim_buf_set_lines(0, 0, 1, false, { '# ' .. date })
      vim.cmd 'write' -- Save the file
    else
      vim.cmd('edit ' .. file_path)
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { '# ' .. date })
      vim.cmd 'write' -- Save the file
    end
  end
end

-- Keybinding to open daily note
vim.keymap.set('n', '<leader>dn', open_daily_note, { desc = 'Open Daily Note' })
