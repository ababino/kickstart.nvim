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
