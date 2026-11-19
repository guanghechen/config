---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.git_files.keymaps" ---@type string

local M = {}

---@return nil
local function show_help()
  require("era.view.keysheet").for_buffer({ bufnr = vim.api.nvim_get_current_buf(), title = "Git Files" }):open()
end

---Keys every pane takes: the focus moves and the refresh of the Picker, in Insert, Normal and Visual mode.
---@param widget                        era.m.git_files.Widget
---@return stl.t.IKeymap[]
local function shared(widget)
  ---@type stl.t.IKeymap[]
  return {
    {
      modes = { "i", "n", "x" },
      key = "<C-a>r",
      aliases = { "<D-r>", "<M-r>" },
      desc = "Git Files: refresh",
      callback = function()
        widget:refresh(false)
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-a>h",
      aliases = { "<D-h>", "<M-h>" },
      desc = "Git Files: focus left",
      callback = function()
        widget:navigate("h")
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-a>j",
      aliases = { "<D-j>", "<M-j>" },
      desc = "Git Files: focus down",
      callback = function()
        widget:navigate("j")
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-a>k",
      aliases = { "<D-k>", "<M-k>" },
      desc = "Git Files: focus up",
      callback = function()
        widget:navigate("k")
      end,
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-a>l",
      aliases = { "<D-l>", "<M-l>" },
      desc = "Git Files: focus right",
      callback = function()
        widget:navigate("l")
      end,
    },
  }
end

---Expansion keys typed ahead decide on the tree their earlier keys produce, in typing order; a key that waits for them
---runs only if the focus stayed where it was pressed.
---@param widget                        era.m.git_files.Widget
---@param callback                      fun(): nil
---@return fun(): nil
local function after_expansion(widget, callback)
  local function gated()
    local pane = widget:current()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    if
      pane.tree:after_collapse(function()
        if vim.api.nvim_get_current_win() == winnr then
          gated()
        end
      end)
    then
      return
    end
    callback()
  end
  return gated
end

---Toggles the expansion of the current row of the most recently used tree and of everything under it.
---@param widget                        era.m.git_files.Widget
---@return nil
local function toggle_recursively(widget)
  local pane, key = widget:current()
  if key then
    pane.tree:collapse(key, "toggle", true)
  end
end

---@param widget                        era.m.git_files.Widget
---@return stl.t.IKeymap[]
function M.tree(widget)
  ---@type stl.t.IKeymap[]
  local keys = {
    {
      modes = { "n", "x" },
      key = "q",
      desc = "Git Files: close",
      callback = function()
        widget:hide()
      end,
    },
    { modes = { "n" }, key = "g?", desc = "Git Files: keymap help", callback = show_help },
    {
      modes = { "n" },
      key = "]p",
      desc = "Git Files: next pane",
      callback = function()
        widget:cycle(1)
      end,
    },
    {
      modes = { "n" },
      key = "[p",
      desc = "Git Files: previous pane",
      callback = function()
        widget:cycle(-1)
      end,
    },
    {
      modes = { "n" },
      key = "<CR>",
      desc = "Git Files: expand or open",
      callback = after_expansion(widget, function()
        widget:activate()
      end),
    },
    {
      modes = { "n" },
      key = "l",
      desc = "Git Files: expand or open",
      callback = after_expansion(widget, function()
        widget:activate()
      end),
    },
    {
      modes = { "n" },
      key = "h",
      desc = "Git Files: collapse or parent",
      callback = after_expansion(widget, function()
        widget:collapse()
      end),
    },
    {
      modes = { "n", "x" },
      key = "gs",
      desc = "Git Files: stage",
      callback = function()
        widget:transfer("unstaged")
      end,
    },
    {
      modes = { "n", "x" },
      key = "gu",
      desc = "Git Files: unstage",
      callback = function()
        widget:transfer("staged")
      end,
    },
    {
      modes = { "n", "x" },
      key = "oc",
      desc = "Git Files: copy paths",
      callback = function()
        widget:copy_paths()
      end,
    },
    {
      modes = { "n", "x" },
      key = "<Tab>",
      desc = "Git Files: toggle selection",
      callback = function()
        widget:toggle_selection(widget._active)
      end,
    },
    {
      modes = { "n" },
      key = "oz",
      desc = "Git Files: recursive expansion",
      callback = after_expansion(widget, function()
        toggle_recursively(widget)
      end),
    },
    {
      modes = { "n" },
      key = "[i",
      desc = "Git Files: parent row",
      callback = function()
        local pane = widget:current()
        if pane.tree.view then
          pane.tree.view:navigate("parent")
        end
      end,
    },
    {
      modes = { "n" },
      key = "]i",
      desc = "Git Files: last child or sibling",
      callback = function()
        local pane = widget:current()
        if pane.tree.view then
          pane.tree.view:navigate("last_child_or_sibling")
        end
      end,
    },
    {
      modes = { "n" },
      key = ".",
      desc = "Git Files: root at cursor",
      callback = function()
        widget:root("cursor")
      end,
    },
    {
      modes = { "n" },
      key = "<BS>",
      desc = "Git Files: parent root",
      callback = function()
        widget:root("parent")
      end,
    },
    {
      modes = { "n" },
      key = "gw",
      desc = "Git Files: workspace root",
      callback = function()
        widget:root("workspace")
      end,
    },
    {
      modes = { "n" },
      key = "/",
      desc = "Git Files: filter both trees",
      callback = function()
        widget:filter()
      end,
    },
    {
      modes = { "n" },
      key = "R",
      desc = "Git Files: refresh",
      callback = function()
        widget:refresh(false)
      end,
    },
    {
      modes = { "n" },
      key = stl.e.ToggleKeyEnum.PREVIEW,
      desc = "Git Files: toggle diff preview",
      callback = function()
        widget:toggle_preview()
      end,
    },
    {
      modes = { "n", "x" },
      key = "z;",
      desc = "Git Files: toggle immersive column",
      callback = function()
        widget:toggle_immersive()
      end,
    },
    {
      modes = { "n" },
      key = stl.e.ToggleKeyEnum.FOLDEMPTY,
      desc = "Git Files: compact directories",
      callback = function()
        widget._foldempty = not widget._foldempty
        for _, pane in pairs(widget.panes) do
          pane.result:mark_content_dirty()
        end
      end,
    },
    {
      modes = { "n" },
      key = "oe",
      desc = "Git Files: directory browser",
      callback = function()
        widget:browse("explorer")
      end,
    },
    {
      modes = { "n" },
      key = "of",
      desc = "Git Files: find files",
      callback = function()
        widget:browse("find")
      end,
    },
    {
      modes = { "n" },
      key = "os",
      desc = "Git Files: search content",
      callback = function()
        widget:browse("search")
      end,
    },
    {
      modes = { "n" },
      key = "oo",
      desc = "Git Files: system open",
      callback = function()
        widget:browse("system")
      end,
    },
    {
      modes = { "n" },
      key = "oi",
      aliases = { "K" },
      desc = "Git Files: file info",
      callback = function()
        widget:browse("info")
      end,
    },
    {
      modes = { "n" },
      key = "<C-q>",
      desc = "Git Files: quickfix",
      callback = function()
        widget:browse("quickfix")
      end,
    },
  }
  return vim.list_extend(keys, shared(widget))
end

---@param widget                        era.m.git_files.Widget
---@return stl.t.IKeymap[]
function M.preview(widget)
  ---@type stl.t.IKeymap[]
  local keys = {
    {
      modes = { "n" },
      key = "q",
      desc = "Git Files: close",
      callback = function()
        widget:hide()
      end,
    },
    { modes = { "n" }, key = "g?", desc = "Git Files: keymap help", callback = show_help },
    {
      modes = { "n", "x" },
      key = "<Tab>",
      desc = "Git Files: noop",
      callback = stl.fn.noop,
    },
    {
      modes = { "n" },
      key = "]h",
      aliases = { "]H", "]j" },
      desc = "Git Files: next hunk",
      callback = function()
        widget.preview:goto_hunk("next")
      end,
    },
    {
      modes = { "n" },
      key = "[h",
      aliases = { "[H", "[j" },
      desc = "Git Files: previous hunk",
      callback = function()
        widget.preview:goto_hunk("prev")
      end,
    },
    {
      modes = { "n" },
      key = stl.e.ToggleKeyEnum.PREVIEW,
      desc = "Git Files: toggle diff preview",
      callback = function()
        widget:toggle_preview()
      end,
    },
  }
  return vim.list_extend(keys, shared(widget))
end

---@param widget                        era.m.git_files.Widget
---@return stl.t.IKeymap[]
function M.input(widget)
  ---@type stl.t.IKeymap[]
  local keys = {
    {
      modes = { "n" },
      key = "q",
      desc = "Git Files: close",
      callback = function()
        widget:hide()
      end,
    },
    { modes = { "n" }, key = "g?", desc = "Git Files: keymap help", callback = show_help },
    {
      modes = { "i", "n" },
      key = "<C-c>",
      desc = "Git Files: close",
      callback = function()
        widget:hide()
      end,
    },
    {
      modes = { "i", "n" },
      key = "<CR>",
      desc = "Git Files: focus target tree",
      callback = function()
        widget:focus(widget:target())
      end,
    },
    {
      modes = { "i", "n" },
      key = "<Tab>",
      desc = "Git Files: toggle target tree selection",
      callback = function()
        widget:toggle_selection()
      end,
    },
    {
      modes = { "i" },
      key = "<S-Tab>",
      desc = "Git Files: noop",
      callback = stl.fn.noop,
    },
    {
      modes = { "n" },
      key = "]p",
      desc = "Git Files: next pane",
      callback = function()
        widget:cycle(1)
      end,
    },
    {
      modes = { "n" },
      key = "[p",
      desc = "Git Files: previous pane",
      callback = function()
        widget:cycle(-1)
      end,
    },
    {
      modes = { "n" },
      key = "j",
      desc = "Git Files: target tree next row",
      callback = function()
        widget:move("down", vim.v.count)
      end,
    },
    {
      modes = { "i", "n" },
      key = "<Down>",
      aliases = { "<C-j>" },
      desc = "Git Files: target tree next row",
      callback = function()
        widget:move("down", vim.v.count)
      end,
    },
    {
      modes = { "n" },
      key = "k",
      desc = "Git Files: target tree previous row",
      callback = function()
        widget:move("up", vim.v.count)
      end,
    },
    {
      modes = { "i", "n" },
      key = "<Up>",
      aliases = { "<C-k>" },
      desc = "Git Files: target tree previous row",
      callback = function()
        widget:move("up", vim.v.count)
      end,
    },
    {
      modes = { "n" },
      key = "gg",
      desc = "Git Files: target tree first row",
      callback = function()
        widget:move("first", vim.v.count)
      end,
    },
    {
      modes = { "n" },
      key = "G",
      desc = "Git Files: target tree last row",
      callback = function()
        widget:move("last", vim.v.count)
      end,
    },
    {
      modes = { "n" },
      key = stl.e.ToggleKeyEnum.PREVIEW,
      desc = "Git Files: toggle diff preview",
      callback = function()
        widget:toggle_preview()
      end,
    },
    {
      modes = { "n" },
      key = "z;",
      desc = "Git Files: toggle immersive column",
      callback = function()
        widget:toggle_immersive()
      end,
    },
  }

  ---A key that acts on the current row of the target tree, as it does on its own row in a tree.
  ---@param key                         string
  ---@param desc                        string
  ---@param action                      fun(): nil
  ---@param aliases                     ?string[]
  ---@return stl.t.IKeymap
  local function on_target(key, desc, action, aliases)
    return {
      modes = { "n" },
      key = key,
      aliases = aliases,
      desc = "Git Files: " .. desc,
      callback = function()
        widget:use_target()
        action()
      end,
    }
  end

  local recursive = after_expansion(widget, function()
    toggle_recursively(widget)
  end)
  -- stylua: ignore
  vim.list_extend(keys, {
    on_target("oc", "copy target tree paths", function() widget:copy_paths() end),
    on_target("oi", "target tree file info", function() widget:browse("info") end, { "K" }),
    on_target("oe", "target tree directory browser", function() widget:browse("explorer") end),
    on_target("of", "target tree find files", function() widget:browse("find") end),
    on_target("os", "target tree search content", function() widget:browse("search") end),
    on_target("oo", "target tree system open", function() widget:browse("system") end),
    on_target("oz", "target tree recursive expansion", recursive),
    on_target("<C-q>", "target tree quickfix", function() widget:browse("quickfix") end),
  })
  return vim.list_extend(keys, shared(widget))
end

return M
