-- https://github.com/kristijanhusak/vim-dadbod-ui
-- db connections and queries

--return {
--  'kristijanhusak/vim-dadbod-ui',
--  dependencies = {
--    { 'tpope/vim-dadbod', lazy = true },
--    { 'kristijanhusak/vim-dadbod-completion', ft = { 'sql', 'mysql', 'plsql' }, lazy = true }, -- Optional
--    { 'tpope/vim-dotenv' },
--  },
--  cmd = {
--    'DBUI',
--    'DBUIToggle',
--    'DBUIAddConnection',
--    'DBUIFindBuffer',
--  },
--  init = function()
--    -- Your DBUI configuration
--    vim.g.db_ui_use_nerd_fonts = 1
--  end,
--}
return {
  'tpope/vim-dadbod',
  'kristijanhusak/vim-dadbod-completion',
  'kristijanhusak/vim-dadbod-ui',
}
