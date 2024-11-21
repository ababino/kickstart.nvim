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

-- Helper functions for date handling
local function get_date_days_ago(days)
    return os.date('%Y-%m-%d', os.time() - (86400 * days))
end

local function is_older_than_days(date_str, days)
    local year, month, day = date_str:match("(%d+)-(%d+)-(%d+)")
    if not year then return false end
    
    local file_time = os.time({year=year, month=month, day=day})
    local cutoff_time = os.time() - (86400 * days)
    return file_time < cutoff_time
end

local function archive_old_notes()
    local daily_dir = '02 Areas/Daily'
    local archive_dir = '04 Archive/Daily'
    
    -- Create archive directory if it doesn't exist
    vim.fn.mkdir(archive_dir, 'p')
    
    -- Get all files in daily directory
    local handle = vim.loop.fs_scandir(daily_dir)
    if not handle then return end
    
    while true do
        local name, type = vim.loop.fs_scandir_next(handle)
        if not name then break end
        
        -- Check only .md files
        if type == "file" and name:match("%.md$") then
            local date_str = name:match("(%d%d%d%d%-%d%d%-%d%d)%.md$")
            if date_str and is_older_than_days(date_str, 7) then
                local source = daily_dir .. '/' .. name
                local target = archive_dir .. '/' .. name
                
                -- Move file to archive
                local success = os.rename(source, target)
                if not success then
                    -- If rename fails (e.g., across devices), try copy and delete
                    if copy_file(source, target) then
                        os.remove(source)
                    end
                end
            end
        end
    end
end

-- Function to create or open daily note
local function open_daily_note()
    -- Archive old notes first
    archive_old_notes()
    
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
