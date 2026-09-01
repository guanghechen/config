local S = era.m.wk

----------------------------------------------------------------------------------------------------
-- State
----------------------------------------------------------------------------------------------------

---@type era.m.wk.ISetupOpts
local DEFAULT_OPTS = {
  preset = "classic",
  delay = 200,
  triggers = { { "<auto>", mode = "nxso" } },
  disable = {
    ft = { stl.filetype.TERM, stl.filetype.WINSEP },
  },
  spec = {
    {
      mode = { "n", "x" },
      ---@diagnostic disable: missing-fields, assign-type-mismatch
      { "g", group = "goto", icon = { icon = stl.icon.ui.Location, color = "blue" } },
      { "gs", group = "surround", icon = { icon = stl.icon.ui.Circle, color = "purple" } },
      { "z", group = "fold", icon = { icon = stl.icon.symbols.flag_fold, color = "yellow" } },
      { "]", group = "next", icon = { icon = stl.icon.ui.Right, color = "cyan" } },
      { "[", group = "prev", icon = { icon = stl.icon.ui.Left, color = "cyan" } },
      { "<leader>a", group = "ai", icon = { icon = stl.icon.app.Copilot, color = "purple" } },
      { "<leader>b", group = "buffer", icon = { icon = stl.icon.ui.Buffer, color = "blue" } },
      { "<leader>0", group = "buffer focus", icon = { icon = stl.icon.ui.Tab, color = "blue" } },
      { "<leader>c", group = "code", icon = { icon = stl.icon.ui.CodeAction, color = "green" } },
      { "<leader>e", group = "explorer", icon = { icon = stl.icon.filetype.FileTree, color = "green" } },
      { "<leader>f", group = "find/file", icon = { icon = stl.icon.ui.Search, color = "cyan" } },
      { "<leader>g", group = "git", icon = { icon = stl.icon.git.Git, color = "red" } },
      { "<leader>gh", group = "git hunk", icon = { icon = stl.icon.git.Diff, color = "yellow" } },
      { "<leader>i", group = "inspect", icon = { icon = stl.icon.ui.Indicator, color = "purple" } },
      { "<leader>n", group = "notepad", icon = { icon = stl.icon.notepad.Notebook, color = "yellow" } },
      { "<leader>p", group = "paste/plugin", icon = { icon = stl.icon.ui.Plugin, color = "cyan" } },
      { "<leader>q", group = "quit/session", icon = { icon = stl.icon.ui.SignOut, color = "red" } },
      { "<leader>s", group = "search/replace", icon = { icon = stl.icon.symbols.flag_replace, color = "purple" } },
      { "<leader>t", group = "tab/toggle", icon = { icon = stl.icon.ui.TabPage, color = "yellow" } },
      { "<leader>u", group = "ui", icon = { icon = stl.icon.ui.Gear, color = "orange" } },
      { "<leader>w", group = "window", proxy = "<c-w>", icon = { icon = stl.icon.ui.Window, color = "green" } },
      { "<leader>x", group = "diagnostics/quickfix", icon = { icon = stl.icon.diagnostic.Warning_alt, color = "red" } },
      ---@diagnostic enable: missing-fields, assign-type-mismatch
    },
  },
}

---@class era.m.wk.state
local M = {
  ---@type boolean Whether which-key is enabled and ready to handle input
  ready = false,
  ---@type era.m.wk.ISetupOpts
  opts = DEFAULT_OPTS,
  ---@type table<integer, table<era.m.wk.Mode, table<string, era.m.wk.INode>>>
  buf_trees = {},
  ---@type table<string, boolean>
  suspended = {},
  ---@type table<{list: era.m.wk.IMapping[], opts: era.m.wk.IAddOpts?}>
  dynamic_specs = {},
  ---@type string
  keys = "",
  ---@type era.m.wk.Mode
  mode = "n",
  ---@type integer
  bufnr = 0,
  ---@type integer|nil
  winnr = nil,
  ---@type integer|nil
  popup_bufnr = nil,
  ---@type number
  started_at = 0,
  ---@type boolean
  show_popup = false,
}

----------------------------------------------------------------------------------------------------
-- Setup
----------------------------------------------------------------------------------------------------

---Setup autocmds (called once during initialization)
function M.setup()
  M.__setup_autocmds__()
end

---Enable which-key (can be called multiple times)
function M.enable()
  if M.ready then
    return
  end
  M.ready = true
  M.__attach__(vim.api.nvim_get_current_buf())
end

---Disable which-key (can be called multiple times)
function M.disable()
  if not M.ready then
    return
  end
  M.ready = false
  S.input.stop()
  for bufnr, _ in pairs(M.buf_trees) do
    for mode, _ in pairs(M.get_trigger_modes()) do
      S.input.detach(bufnr, mode)
    end
  end
end

---Reset session state (called when stopping input)
function M.reset()
  M.keys = ""
  M.winnr = nil
  M.popup_bufnr = nil
  M.started_at = 0
  M.show_popup = false
end

---Suspend triggers for buffer/mode
---@param bufnr                          integer
---@param mode                           string
function M.suspend(bufnr, mode)
  M.suspended[bufnr .. ":" .. mode] = true
  S.input.detach(bufnr, mode)
end

---Resume triggers
---@param bufnr                          integer
---@param mode                           string
function M.resume(bufnr, mode)
  M.suspended[bufnr .. ":" .. mode] = nil
  S.input.attach(bufnr)
end

---Schedule resume on next tick (macro-safe)
---@param bufnr                          integer
---@param mode                           string
function M.schedule_resume(bufnr, mode)
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then
      M.suspended[bufnr .. ":" .. mode] = nil
      return
    end
    if S.util.in_macro() then
      vim.defer_fn(function()
        if vim.api.nvim_buf_is_valid(bufnr) and not S.util.in_macro() then
          M.resume(bufnr, mode)
        else
          M.suspended[bufnr .. ":" .. mode] = nil
        end
      end, 100)
      return
    end
    M.resume(bufnr, mode)
  end)
end

---Check if suspended
---@param bufnr                          integer
---@param mode                           string
---@return boolean
function M.is_suspended(bufnr, mode)
  return M.suspended[bufnr .. ":" .. mode] == true
end

---Get delay for current context
---@return integer
function M.get_delay()
  local delay = M.opts.delay or 200
  if type(delay) == "function" then
    return delay({ mode = M.mode, keys = M.keys })
  end
  return delay
end

----------------------------------------------------------------------------------------------------
-- Mapping
----------------------------------------------------------------------------------------------------

---Add mappings (public API)
---@param mappings                       era.m.wk.IMapping | era.m.wk.IMapping[]
---@param opts                           ?era.m.wk.IAddOpts
function M.add(mappings, opts)
  if not M.ready then
    vim.schedule(function()
      M.add(mappings, opts)
    end)
    return
  end

  opts = opts or {}

  -- Normalize to list: single mapping -> { mapping }
  local is_single = type(mappings[1]) == "string"
  local list = is_single and { mappings } or mappings

  -- Save for future buffers
  M.dynamic_specs[#M.dynamic_specs + 1] = { list = list, opts = opts }

  for _, spec in ipairs(list) do
    ---@diagnostic disable-next-line: param-type-mismatch
    M.__add_spec__(spec, opts)
  end
end

---Add a single spec (handles mode inheritance)
---@param spec                           era.m.wk.IMapping
---@param opts                           ?era.m.wk.IAddOpts
function M.__add_spec__(spec, opts)
  if spec.mode then
    ---@diagnostic disable-next-line: param-type-mismatch
    local modes = type(spec.mode) == "string" and S.util.parse_modes(spec.mode) or spec.mode
    for _, child in ipairs(spec) do
      if type(child) == "table" and child[1] then
        child.mode = child.mode or modes
        M.__add_to_all_bufs__(child, opts)
      end
    end
  else
    M.__add_to_all_bufs__(spec, opts)
  end
end

---Get tree for current buffer and mode
---@return table<string, era.m.wk.INode>
function M.get_tree()
  local buf_tree = M.buf_trees[M.bufnr]
  if not buf_tree then
    return {}
  end
  return buf_tree[M.mode] or {}
end

---Get available keys for current state
---@return table<string, era.m.wk.INode>
function M.get_available()
  return S.tree.get_children(M.get_tree(), M.keys, M.mode)
end

---Get node at path
---@param keys                           string
---@return era.m.wk.INode|nil
function M.get_node(keys)
  local tree_tbl = M.get_tree()
  if not tree_tbl then
    return nil
  end
  return S.tree.find(tree_tbl, keys)
end

---Process expand functions
---@param nodes                          table<string, era.m.wk.INode>
---@return table<string, era.m.wk.INode>
function M.expand(nodes)
  local result = {}
  for key, node in pairs(nodes) do
    result[key] = node
    if node.expand then
      local expanded = node.expand()
      if expanded then
        for _, mapping in ipairs(expanded) do
          if mapping[1] then
            local prefixed = vim.deepcopy(mapping)
            local modes = prefixed.mode or { M.mode }
            if type(modes) == "string" then
              modes = S.util.parse_modes(modes)
            end
            prefixed[1] = (node.lhs or "") .. prefixed[1]
            M.__add_mapping__(M.bufnr, prefixed, { mode = modes })
          end
        end
        for k, n in pairs(M.get_available()) do
          if not result[k] then
            result[k] = n
          end
        end
      end
    end
  end
  return result
end

----------------------------------------------------------------------------------------------------
-- Config helpers
----------------------------------------------------------------------------------------------------

---Check if filetype is disabled
---@param ft                             string
---@return boolean
function M.is_disabled(ft)
  if not M.opts.disable or not M.opts.disable.ft then
    return false
  end
  for _, disabled in ipairs(M.opts.disable.ft) do
    if ft == disabled then
      return true
    end
  end
  return false
end

---Get enabled trigger modes
---@return table<string, boolean>
function M.get_trigger_modes()
  local modes = {}
  for _, trigger in ipairs(M.opts.triggers or {}) do
    if trigger[1] == "<auto>" and trigger.mode then
      for i = 1, #trigger.mode do
        modes[trigger.mode:sub(i, i)] = true
      end
    end
  end
  return modes
end

----------------------------------------------------------------------------------------------------
-- Protected
----------------------------------------------------------------------------------------------------

---Add mapping to specific buffer
---@param bufnr                          integer
---@param mapping                        era.m.wk.IMapping
---@param opts                           ?era.m.wk.IAddOpts
function M.__add_mapping__(bufnr, mapping, opts)
  opts = opts or {}
  local modes = mapping.mode or opts.mode or { "n" }
  if type(modes) == "string" then
    modes = S.util.parse_modes(modes)
  end

  if not M.buf_trees[bufnr] then
    M.buf_trees[bufnr] = {}
  end

  for _, mode in ipairs(modes) do
    if not M.buf_trees[bufnr][mode] then
      M.buf_trees[bufnr][mode] = S.tree.new()
    end
    S.tree.add(M.buf_trees[bufnr][mode], mapping)
  end
end

---Add mapping to all existing buffers
---@param mapping                        era.m.wk.IMapping
---@param opts                           ?era.m.wk.IAddOpts
function M.__add_to_all_bufs__(mapping, opts)
  for bufnr, _ in pairs(M.buf_trees) do
    M.__add_mapping__(bufnr, mapping, opts)
  end
end

---Attach to buffer
---@param bufnr                          integer
function M.__attach__(bufnr)
  if not M.ready then
    return
  end

  if
    not vim.api.nvim_buf_is_valid(bufnr) or M.is_disabled(vim.api.nvim_get_option_value("filetype", { buf = bufnr }))
  then
    return
  end

  if M.buf_trees[bufnr] then
    S.input.attach(bufnr)
    return
  end

  M.buf_trees[bufnr] = {}

  for mode, _ in pairs(M.get_trigger_modes()) do
    M.__load_keymaps__(bufnr, mode)
  end

  if M.opts.spec then
    for _, spec in ipairs(M.opts.spec) do
      M.__load_spec__(bufnr, spec)
    end
  end

  for _, d in ipairs(M.dynamic_specs) do
    local modes = d.opts and d.opts.mode
    for _, spec in ipairs(d.list) do
      M.__load_spec__(bufnr, spec, modes)
    end
  end

  S.input.attach(bufnr)
end

---Check if keymap is valid for which-key
---@param km                             table
---@return boolean
function M.__is_valid_keymap__(km)
  if km.desc and km.desc:find("wk-trigger", 1, true) then
    return false
  end
  if km.lhs:sub(1, 6) == "<Plug>" or km.lhs:sub(1, 5) == "<SNR>" then
    return false
  end
  if km.rhs and (km.rhs == "" or km.rhs:lower() == "<nop>") then
    return false
  end
  return true
end

---Load keymaps from Neovim into tree
---@param bufnr                          integer
---@param mode                           string
function M.__load_keymaps__(bufnr, mode)
  if not M.buf_trees[bufnr] then
    M.buf_trees[bufnr] = {}
  end

  M.buf_trees[bufnr][mode] = S.tree.new()
  local tree_tbl = M.buf_trees[bufnr][mode]

  ---@param keymaps table[]
  local function load_keymaps(keymaps)
    for _, km in ipairs(keymaps) do
      if M.__is_valid_keymap__(km) then
        -- For Neovim keymaps, don't save callback/rhs - we'll use feedkeys for execution
        -- Only save description for display purposes
        S.tree.add(tree_tbl, {
          S.util.normalize_lhs(km.lhs),
          nil, -- no rhs/action - will use feedkeys
          desc = km.desc or (type(km.rhs) == "string" and km.rhs) or km.lhs,
          nowait = km.nowait == 1,
        })
      end
    end
  end

  load_keymaps(vim.api.nvim_get_keymap(mode))
  load_keymaps(vim.api.nvim_buf_get_keymap(bufnr, mode))
end

---Load spec recursively into buffer tree
---@param bufnr                          integer
---@param spec                           era.m.wk.IMapping
---@param parent_modes                   era.m.wk.Mode[]?
function M.__load_spec__(bufnr, spec, parent_modes)
  local modes = spec.mode or parent_modes or { "n" }
  if type(modes) == "string" then
    modes = S.util.parse_modes(modes)
  end

  if spec[1] and type(spec[1]) == "string" then
    M.__add_mapping__(bufnr, spec, { mode = modes })
  end

  for _, child in ipairs(spec) do
    if type(child) == "table" then
      M.__load_spec__(bufnr, child, modes)
    end
  end
end

---Setup autocmds
function M.__setup_autocmds__()
  local group = vim.api.nvim_create_augroup("WhichKey", { clear = true })

  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function(ev)
      M.__attach__(ev.buf)
    end,
  })

  vim.api.nvim_create_autocmd("ModeChanged", {
    group = group,
    pattern = "*:*",
    callback = function()
      if S.util.get_mapmode() ~= M.mode then
        S.input.stop()
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave", "CmdlineEnter", "InsertEnter" }, {
    group = group,
    callback = function()
      S.input.stop()
    end,
  })

  vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    callback = function(ev)
      M.buf_trees[ev.buf] = nil
      for mode, _ in pairs(M.get_trigger_modes()) do
        M.suspended[ev.buf .. ":" .. mode] = nil
        S.input.detach(ev.buf, mode)
      end
    end,
  })

  -- Handle macro recording
  vim.api.nvim_create_autocmd({ "RecordingEnter", "RecordingLeave" }, {
    group = group,
    callback = function(ev)
      if ev.event == "RecordingEnter" then
        S.input.stop()
      else
        S.input.attach(vim.api.nvim_get_current_buf())
      end
    end,
  })
end

return M
