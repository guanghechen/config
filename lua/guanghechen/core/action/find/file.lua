local action_autocmd = require("guanghechen.core.action.autocmd")

---@alias IFindFileContext { workspace: string, cwd: string, directory: string, bufnr: number }

---@param find_file_context IFindFileContext
---@param scope ghc.enums.context.FindScope
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

---@param scope ghc.enums.context.FindScope
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

---@param scope ghc.enums.context.FindScope
---@return ghc.enums.context.FindScope
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
  local filemap_filepath = fml.path.locate_session_filepath({ filename = "filemap.json" })
  if force or not fml.path.is_exist(filemap_filepath) or ghc.context.transient.filemap_dirty:get_snapshot() then
    local stdout = vim.uv.new_pipe(false)
    local stderr = vim.uv.new_pipe(false)
    local subprocess
    local function on_exit(code, signal)
      stdout:read_stop()
      stderr:read_stop()
      stdout:close()
      stderr:close()
      subprocess:close()
      if code ~= 0 then
        fml.reporter.warn({
          from = "guanghechen.core.action.find.file",
          subject = "gen_filemap",
          message = "failed!",
          details = { code = code, signal = signal },
        })
      end
    end

    -- clear filemap content
    os.remove(filemap_filepath)

    subprocess = vim.uv.spawn("fd", {
      cwd = cwd,
      args = { "--hidden", "--type=file", "--color=never" },
      stdio = { nil, stdout, stderr },
    }, on_exit)

    vim.uv.read_start(stdout, function(err, data)
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
    ghc.context.transient.filemap_dirty:next(false)
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
    workspace = fml.path.workspace(),
    cwd = fml.path.cwd(),
    directory = fml.path.current_directory(),
    bufnr = vim.api.nvim_get_current_buf(),
  }

  opts = opts or {}
  opts.initial_mode = "normal"
  opts.bufnr = find_file_context.bufnr
  opts.show_untracked = true
  opts.workspace = "CWD"
  opts.use_regex = ghc.context.session.search_flag_regex:get_snapshot()

  ---@type ghc.enums.context.FindScope
  local scope0 = ghc.context.session.find_scope:get_snapshot()
  opts.cwd = get_cwd_by_scope(find_file_context, scope0)

  ---@type string
  local filemap_filepath = gen_filemap(force, opts.cwd)

  ---@type fun():nil
  local open_picker

  ---@param scope_next ghc.enums.context.FindScope
  local function change_scope(scope_next)
    local scope_current = ghc.context.session.find_scope:get_snapshot()
    if scope_next ~= scope_current then
      ghc.context.session.find_scope:next(scope_next)
      ghc.context.transient.filemap_dirty:next(true)
      open_picker()
    end
  end

  local actions = {
    show_last_find_file_cmd = function()
      local last_cmd = ghc.context.transient.find_file_last_command:get_snapshot() or {}
      fml.reporter.info({
        from = "guanghechen.core.action.find.file",
        subject = "show_last_find_file_cmd",
        details = {
          context = find_file_context,
          last_cmd = last_cmd,
        },
      })
    end,
    toggle_enable_regex = function()
      local next_flag_regex = ghc.context.session.search_flag_regex:get_snapshot() ---@type boolean
      ghc.context.session.search_flag_regex:next(next_flag_regex)
      opts.use_regex = next_flag_regex
      open_picker()
    end,
    toggle_case_sensitive = function()
      ghc.context.session.search_flag_case_sensitive:next(
        not ghc.context.session.search_flag_case_sensitive:get_snapshot()
      )
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
      ---@type ghc.enums.context.FindScope
      local scope = ghc.context.session.find_scope:get_snapshot()
      local scope_next = toggle_scope_carousel(scope)
      change_scope(scope_next)
    end,
  }

  local function build_find_file_command(prompt)
    if prompt then
      ghc.context.session.find_file_pattern:next(prompt)
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
    if not ghc.context.session.search_flag_regex:get_snapshot() then
      table.insert(cmd, "--fixed-strings")
    end
    if ghc.context.session.search_flag_case_sensitive:get_snapshot() then
      table.insert(cmd, "--case-sensitive")
    else
      table.insert(cmd, "--ignore-case")
    end
    table.insert(cmd, "--")
    table.insert(cmd, prompt)
    table.insert(cmd, filemap_filepath)

    ghc.context.transient.find_file_last_command:next(fml.array.slice(cmd))
    return cmd
  end

  open_picker = function()
    ---@type ghc.enums.context.FindScope
    local scope = ghc.context.session.find_scope:get_snapshot()
    opts.cwd = get_cwd_by_scope(find_file_context, scope)
    opts.entry_maker = vim.F.if_nil(opts.entry_maker, make_entry.gen_from_file(opts))
    gen_filemap(false, opts.cwd)

    local picker_params = {
      prompt_title = "Find files (" .. get_display_name_of_scope(scope) .. ")",
      default_text = ghc.context.session.find_file_pattern:get_snapshot() or "",
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

        ---@type guanghechen.core.types.enum.BUFTYPE_EXTRA
        local buftype_extra = "find_file"
        ghc.context.transient.buftype_extra:next(buftype_extra)

        action_autocmd.autocmd_clear_buftype_extra(prompt_bufnr)
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

---@class guanghechen.core.action.find
local M = require("guanghechen.core.action.find.module")

function M.find_file()
  find_file(nil, false)
end

function M.find_file_force()
  find_file(nil, true)
end
