---@class ghc.core.action.find_file.context
local context = {
  repo = require("ghc.core.context.repo"),
}

---@class ghc.core.action.find_file.util
local util = {
  path = require("ghc.core.util.path"),
  table = require("ghc.core.util.table"),
}

local autocmd = require("ghc.core.action.autocmd")

---@alias IFindFileContext { workspace: string, cwd: string, directory: string, bufnr: number }

---@param find_file_context IFindFileContext
---@param scope ghc.core.types.enum.FIND_FILE_SCOPE
local function get_cwd_by_scope(find_file_context, scope)
  if scope == "W" then
    return find_file_context.workspace
  end

  if scope == "C" then
    return find_file_context.cwd
  end

  if scope == "D" then
    return find_file_context.directory
  end

  return find_file_context.cwd
end

---@param scope ghc.core.types.enum.FIND_FILE_SCOPE
---@return string
local function get_display_name_of_scope(scope)
  if scope == "W" then
    return "workspace"
  end

  if scope == "C" then
    return "cwd"
  end

  if scope == "D" then
    return "directory"
  end

  return "cwd"
end

---@param scope ghc.core.types.enum.FIND_FILE_SCOPE
---@return ghc.core.types.enum.FIND_FILE_SCOPE
local function toggle_scope_carousel(scope)
  if scope == "W" then
    return "C"
  end

  if scope == "C" then
    return "D"
  end

  if scope == "D" then
    return "W"
  end

  return "C"
end

---@param force boolean
---@param cwd string
---@return string
local function gen_filemap(force, cwd)
  local filemap_filepath = util.path.gen_session_related_filepath({ filename = "filemap.json" })
  if force or not util.path.exist(filemap_filepath) or context.repo.filemap_dirty:get_snapshot() then
    local stdout = vim.loop.new_pipe(false)
    local stderr = vim.loop.new_pipe(false)
    local subprocess
    local function on_exit(code, signal)
      stdout:read_stop()
      stderr:read_stop()
      stdout:close()
      stderr:close()
      subprocess:close()
      if code ~= 0 then
        vim.notify("[gen_filemap] failed with code " .. code .. " and signal " .. signal)
      end
    end

    -- clear filemap content
    os.remove(filemap_filepath)

    subprocess = vim.loop.spawn("fd", {
      cwd = cwd,
      args = { "--hidden", "--type=file", "--color=never" },
      stdio = { nil, stdout, stderr },
    }, on_exit)

    vim.loop.read_start(stdout, function(err, data)
      assert(not err, err)
      if data then
        local file = io.open(filemap_filepath, "a")
        if file then
          file:write(data)
          file:close()
        end
      else
        stdout:read_stop()
      end
    end)
    context.repo.filemap_dirty:next(false)
  end
  return filemap_filepath
end

---@param opts? table
---@param force boolean
local function find_file(opts, force)
  ---@diagnostic disable-next-line: undefined-field
  local conf = require("telescope.config").values
  local finders = require("telescope.finders")
  local make_entry = require("telescope.make_entry")
  local pickers = require("telescope.pickers")
  local sorters = require("telescope.sorters")

  ---@type IFindFileContext
  local find_file_context = {
    workspace = util.path.workspace(),
    cwd = util.path.cwd(),
    directory = util.path.current_directory(),
    bufnr = vim.api.nvim_get_current_buf(),
  }
  context.repo.caller_winnr:next(vim.api.nvim_get_current_win())
  context.repo.caller_bufnr:next(vim.api.nvim_get_current_buf())

  opts = opts or {}
  opts.initial_mode = "normal"
  opts.bufnr = find_file_context.bufnr
  opts.show_untracked = true
  opts.workspace = "CWD"
  opts.use_regex = context.repo.find_file_enable_regex:get_snapshot()

  ---@type ghc.core.types.enum.FIND_FILE_SCOPE
  local scope0 = context.repo.find_file_scope:get_snapshot()
  opts.cwd = get_cwd_by_scope(find_file_context, scope0)

  ---@type string
  local filemap_filepath = gen_filemap(force, opts.cwd)

  ---@type fun():nil
  local open_picker

  ---@param scope_next ghc.core.types.enum.FIND_FILE_SCOPE
  local function change_scope(scope_next)
    local scope_current = context.repo.find_file_scope:get_snapshot()
    if scope_next ~= scope_current then
      context.repo.find_file_scope:next(scope_next)
      context.repo.filemap_dirty:next(true)
      open_picker()
    end
  end

  local actions = {
    show_last_find_file_cmd = function()
      local last_cmd = context.repo.find_file_last_command:get_snapshot() or {}
      vim.notify("finding files:" .. "[" .. vim.inspect(find_file_context) .. "]" .. vim.inspect(last_cmd))
    end,
    toggle_enable_regex = function()
      context.repo.find_file_enable_regex:next(not context.repo.find_file_enable_regex:get_snapshot())
      opts.use_regex = context.repo.find_file_enable_regex:get_snapshot()
      open_picker()
    end,
    toggle_case_sensitive = function()
      context.repo.find_file_enable_case_sensitive:next(not context.repo.find_file_enable_case_sensitive:get_snapshot())
      open_picker()
    end,
    change_scope_workspace = function()
      change_scope("W")
    end,
    change_scope_cwd = function()
      change_scope("C")
    end,
    change_scope_directory = function()
      change_scope("D")
    end,
    change_scope_carousel = function()
      ---@type ghc.core.types.enum.FIND_FILE_SCOPE
      local scope = context.repo.find_file_scope:get_snapshot()
      local scope_next = toggle_scope_carousel(scope)
      change_scope(scope_next)
    end,
  }

  local function build_find_file_command(prompt)
    if prompt then
      context.repo.find_file_keyword:next(prompt)
    else
      prompt = ""
    end

    local cmd = {
      "rg",
      "--hidden",
      "--color=never",
      "--no-heading",
      "--no-filename",
      "--no-line-number",
      "--no-column",
      "--no-follow",
    }
    if not context.repo.find_file_enable_regex:get_snapshot() then
      table.insert(cmd, "--fixed-strings")
    end
    if context.repo.find_file_enable_case_sensitive:get_snapshot() then
      table.insert(cmd, "--case-sensitive")
    else
      table.insert(cmd, "--ignore-case")
    end
    table.insert(cmd, "--")
    table.insert(cmd, prompt)
    table.insert(cmd, filemap_filepath)

    context.repo.find_file_last_command:next(util.table.clone_array(cmd))
    return cmd
  end

  open_picker = function()
    ---@type ghc.core.types.enum.FIND_FILE_SCOPE
    local scope = context.repo.find_file_scope:get_snapshot()
    opts.cwd = get_cwd_by_scope(find_file_context, scope)
    opts.entry_maker = vim.F.if_nil(opts.entry_maker, make_entry.gen_from_file(opts))
    gen_filemap(false, opts.cwd)

    local picker_params = {
      prompt_title = "Find files (" .. get_display_name_of_scope(scope) .. ")",
      default_text = context.repo.find_file_keyword:get_snapshot() or "",
      attach_mappings = function(prompt_bufnr)
        local function mapkey(mode, key, action, desc)
          vim.keymap.set(mode, key, action, { buffer = prompt_bufnr, silent = true, noremap = true, desc = desc })
        end

        if opts.mappings then
          for mode, mappings in pairs(opts.mappings) do
            for key, action in pairs(mappings) do
              mapkey(mode, key, action)
            end
          end
        end

        mapkey("n", "<leader>n", actions.show_last_find_file_cmd)
        mapkey("n", "<leader>i", actions.toggle_case_sensitive)
        mapkey("n", "<leader>r", actions.toggle_enable_regex)
        mapkey("n", "<leader>w", actions.change_scope_workspace)
        mapkey("n", "<leader>c", actions.change_scope_cwd)
        mapkey("n", "<leader>d", actions.change_scope_directory)
        mapkey("n", "<leader>s", actions.change_scope_carousel)

        ---@type ghc.core.types.enum.BUFTYPE_EXTRA
        local buftype_extra = "find_file"
        context.repo.buftype_extra:next(buftype_extra)

        autocmd.autocmd_clear_buftype_extra()
        return true
      end,
    }

    opts.entry_maker = make_entry.gen_from_file(opts)
    picker_params.finder = finders.new_job(build_find_file_command, opts.entry_maker, opts.max_results, opts.cwd)
    picker_params.previewer = conf.grep_previewer(opts)
    picker_params.sorter = sorters.highlighter_only(opts)
    pickers.new(opts, picker_params):find()
  end

  open_picker()
end

---@class ghc.core.action.find_file
local M = {}

function M.find_file()
  find_file(nil, false)
end

function M.find_file_force()
  find_file(nil, true)
end

return M
