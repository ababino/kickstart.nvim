-- Neo-tree is a Neovim plugin to browse the file system
-- https://github.com/nvim-neo-tree/neo-tree.nvim
--
-- Adds an "A" mapping in Neo-tree to archive a project (PARA):
-- - Press A on any file/folder inside 01 Projects/<project>/ to move the whole project
--   into 04 Archive/<project> (uses `git mv` if repo is detected, else fs rename).
-- - If a PARA root isn't obvious, you can set:  vim.g.para_root = "/path/to/your/vault"

return {
  'nvim-neo-tree/neo-tree.nvim',
  version = '*',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-tree/nvim-web-devicons', -- not strictly required, but recommended
    'MunifTanjim/nui.nvim',
  },
  cmd = 'Neotree',
  keys = {
    { '\\', ':Neotree reveal<CR>', desc = 'NeoTree reveal', silent = true },
  },
  opts = function(_, opts)
    -- Keep existing opts structure
    opts = opts or {}
    opts.filesystem = opts.filesystem or {}
    opts.filesystem.window = opts.filesystem.window or {}
    opts.filesystem.window.mappings = opts.filesystem.window.mappings or {}

    -- Preserve your close mapping
    opts.filesystem.window.mappings['\\'] = opts.filesystem.window.mappings['\\'] or 'close_window'

    -- ========= Helpers =========
    local uv = vim.uv or vim.loop
    local inputs = require 'neo-tree.ui.inputs'

    local function join(a, b)
      return (a:gsub('/+$', '')) .. '/' .. (b:gsub('^/+', ''))
    end

    local function exists(p)
      return uv.fs_stat(p) ~= nil
    end

    -- Find PARA root by walking up for "04 Archive" and "01 Projects" (also tolerates "01 Projecst")
    local function find_para_root(start)
      local dir = start
      while dir and dir ~= '' and dir ~= '/' do
        local has_archive = exists(join(dir, '04 Archive'))
        local has_projects = exists(join(dir, '01 Projects')) or exists(join(dir, '01 Projecst'))
        if has_archive and has_projects then
          return dir
        end
        local parent = vim.fs.dirname(dir)
        if parent == dir then
          break
        end
        dir = parent
      end
      return vim.g.para_root
    end

    -- Given any path, return the immediate child under "01 Projects/*"
    local function project_dir_for(path)
      local st = uv.fs_stat(path)
      local dir = (st and st.type == 'file') and vim.fs.dirname(path) or path
      while dir and dir ~= '' and dir ~= '/' do
        local parent = vim.fs.dirname(dir)
        local parent_name = vim.fs.basename(parent)
        if parent_name and parent_name:match '^01%s+Proj' then
          return dir
        end
        if parent == dir then
          break
        end
        dir = parent
      end
      -- Fallback: archive exactly what was chosen
      return path
    end

    local function git_root_for(dir)
      local d = dir
      while d and d ~= '' and d ~= '/' do
        if exists(join(d, '.git')) then
          return d
        end
        local parent = vim.fs.dirname(d)
        if parent == d then
          break
        end
        d = parent
      end
      return nil
    end

    local function fs_move_any(src, dst)
      -- 1) try libuv rename (fast path, same filesystem)
      local ok, err = (vim.uv or vim.loop).fs_rename(src, dst)
      if ok then
        return true
      end

      -- 2) fallback to OS move (handles directories & cross-device)
      local cmd
      if vim.fn.has 'win32' == 1 then
        cmd = { 'cmd', '/C', 'move', '/Y', src, dst }
      else
        cmd = { 'mv', '-f', src, dst }
      end

      local code
      if vim.system then
        code = vim.system(cmd):wait().code
      else
        vim.fn.system(cmd)
        code = vim.v.shell_error
      end

      if code == 0 then
        return true
      end
      return nil, err or 'shell mv failed'
    end

    local function move_path(src, dst)
      vim.fn.mkdir(vim.fs.dirname(dst), 'p')
      local root = git_root_for(src)

      if root then
        -- Try git mv first (keeps history when possible)
        local ok
        if vim.system then
          ok = vim.system({ 'git', 'mv', '-k', src, dst }, { cwd = root }):wait().code == 0
        else
          vim.fn.system { 'git', '-C', root, 'mv', '-k', src, dst }
          ok = (vim.v.shell_error == 0)
        end
        if ok then
          return true
        end

        -- Fallback: raw move so the archive always happens
        local ok2, err2 = fs_move_any(src, dst)
        if not ok2 then
          return nil, err2
        end

        -- Best effort: update the index so Git sees deletes/adds.
        -- (Rename will be detected at commit time; no history is lost beyond that.)
        if vim.system then
          vim.system({ 'git', 'add', '-A', '--', dst }, { cwd = root }):wait()
          vim.system({ 'git', 'add', '-A', '-u' }, { cwd = root }):wait()
        else
          vim.fn.system { 'git', '-C', root, 'add', '-A', '--', dst }
          vim.fn.system { 'git', '-C', root, 'add', '-A', '-u' }
        end
        return true
      else
        -- Not a git repo: just move it
        return fs_move_any(src, dst)
      end
    end

    local function archive_nodes(state, nodes)
      -- de-duplicate by project dir
      local uniq = {}
      for _, n in ipairs(nodes) do
        local p = project_dir_for(n:get_id() or n.path)
        uniq[p] = true
      end

      local moved = 0
      for src, _ in pairs(uniq) do
        local para_root = find_para_root(src)
        if not para_root then
          vim.notify('Could not find PARA root for: ' .. src, vim.log.levels.ERROR)
        else
          local dest = join(join(para_root, '04 Archive'), vim.fs.basename(src))
          if exists(dest) then
            dest = dest .. '-' .. os.date '%Y-%m-%d'
          end
          local ok, err = move_path(src, dest)
          if not ok then
            vim.notify(('Move failed: %s → %s (%s)'):format(src, dest, tostring(err)), vim.log.levels.ERROR)
          else
            moved = moved + 1
          end
        end
      end

      if moved > 0 then
        require('neo-tree.sources.manager').refresh(state)
        vim.notify('Archived ' .. moved .. ' project(s) to 04 Archive/')
      end
    end

    -- ========= Commands & Mapping =========
    opts.commands = opts.commands or {}

    opts.commands.archive_project = function(state, selected_nodes)
      -- If user has a selection, archive those; else archive the node under cursor
      local nodes = selected_nodes
      if not nodes or #nodes == 0 then
        local node = state.tree:get_node()
        if not node or node.type == 'message' then
          return
        end
        nodes = { node }
      end

      -- Just for a friendlier prompt name when single node
      local target_path = project_dir_for((nodes[1] and (nodes[1].get_id and nodes[1]:get_id()) or nodes[1].path))
      local pretty = vim.fs.basename(target_path)
      local prompt = (#nodes > 1) and ('Archive %d item(s) to 04 Archive/?'):format(#nodes) or ("Archive project '%s' to 04 Archive/?"):format(pretty)

      inputs.confirm(prompt, function(yes)
        if yes then
          archive_nodes(state, nodes)
        end
      end)
    end

    -- Map "A" to our command
    opts.filesystem.window.mappings['A'] = 'archive_project'

    return opts
  end,
}
