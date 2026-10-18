---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.git_files.keymaps" ---@type string

local M = {}

---@param widget                        era.m.git_files.Widget
---@return stl.t.IKeymap[]
local function navigation(widget)
  ---@type stl.t.IKeymap[]
  return {
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

---@param widget                        era.m.git_files.Widget
---@return stl.t.IKeymap[]
function M.tree(widget)
  -- Expansion keys typed ahead decide on the tree their earlier keys produce, in typing order.
  ---@param callback                    fun(): nil
  ---@return fun(): nil
  local function after_expansion(callback)
    local function gated()
      local pane = widget:current()
      if
        pane.tree:after_collapse(function()
          if pane.result:isfocused() then
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
    {
      modes = { "n" },
      key = "<Tab>",
      desc = "Git Files: switch pane",
      callback = function()
        widget:focus(widget._active == "unstaged" and "staged" or "unstaged")
      end,
    },
    {
      modes = { "n" },
      key = "<S-Tab>",
      desc = "Git Files: switch pane",
      callback = function()
        widget:focus(widget._active == "unstaged" and "staged" or "unstaged")
      end,
    },
    {
      modes = { "n" },
      key = "<CR>",
      desc = "Git Files: expand or open",
      callback = after_expansion(function()
        widget:activate()
      end),
    },
    {
      modes = { "n" },
      key = "l",
      desc = "Git Files: expand or open",
      callback = after_expansion(function()
        widget:activate()
      end),
    },
    {
      modes = { "n" },
      key = "h",
      desc = "Git Files: collapse or parent",
      callback = after_expansion(function()
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
      key = "m",
      desc = "Git Files: toggle selection",
      callback = function()
        local pane = widget:current()
        if pane.tree.view then
          pane.tree.view:select("toggle_node", false):catch(function(error)
            stl.reporter.warn({ from = __module_name__, subject = "select", message = tostring(error) })
          end)
        end
      end,
    },
    {
      modes = { "n" },
      key = "z",
      desc = "Git Files: recursive expansion",
      callback = after_expansion(function()
        local pane, key = widget:current()
        if key then
          pane.tree:collapse(key, "toggle", true)
        end
      end),
    },
    {
      modes = { "n" },
      key = "W",
      desc = "Git Files: collapse all",
      callback = after_expansion(function()
        local pane = widget:current()
        if pane.tree.root then
          pane.tree:collapse(pane.tree.root, "collapse", true)
        end
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
      key = "tp",
      desc = "Git Files: toggle diff preview",
      callback = function()
        widget:toggle_preview()
      end,
    },
    {
      modes = { "n" },
      key = "tf",
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
      key = "<C-q>",
      desc = "Git Files: quickfix",
      callback = function()
        widget:browse("quickfix")
      end,
    },
  }
  return vim.list_extend(keys, navigation(widget))
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
    {
      modes = { "n" },
      key = "<Tab>",
      desc = "Git Files: focus previous pane",
      callback = function()
        widget:focus(widget._last_left)
      end,
    },
    {
      modes = { "n" },
      key = "tp",
      desc = "Git Files: toggle diff preview",
      callback = function()
        widget:toggle_preview()
      end,
    },
  }
  return vim.list_extend(keys, navigation(widget))
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
      desc = "Git Files: focus current tree",
      callback = function()
        widget:focus(widget._active)
      end,
    },
    {
      modes = { "i", "n" },
      key = "<Tab>",
      desc = "Git Files: focus Staged",
      callback = function()
        widget:focus("staged")
      end,
    },
    {
      modes = { "i", "n" },
      key = "<S-Tab>",
      desc = "Git Files: focus Unstaged",
      callback = function()
        widget:focus("unstaged")
      end,
    },
    {
      modes = { "n" },
      key = "tp",
      desc = "Git Files: toggle diff preview",
      callback = function()
        widget:toggle_preview()
      end,
    },
  }
  return vim.list_extend(keys, navigation(widget))
end

return M
