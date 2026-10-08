---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.explorer.keymaps" ---@type string

local Session = require("era.m.explorer.session")
local M = {}

---@param widget                        era.m.explorer.Widget
---@param view                          ux.filetree.View
---@return nil
function M.bind(widget, view)
  local action = widget._action
  ---@param method                      string
  ---@param ...                         any
  ---@return nil
  local function invoke(method, ...)
    local ok, value = pcall(action[method], action, ...)
    if not ok then
      Session.report(value)
    elseif type(value) == "table" and value.finally then
      value:finally(function(resolved, result)
        if view._closed then
          return
        end
        if not resolved then
          Session.report(result)
        elseif type(result) == "table" and result.kind == "Rejected" then
          Session.report(result.error)
        end
      end)
    end
  end
  ---@type stl.t.IKeymap[]
  local keymaps = {
    {
      modes = { "n", "x" },
      key = "<Esc><Esc>",
      desc = "Explorer: cancel transfer or clear selection",
      callback = function()
        invoke("cancel_transfer_or_clear_selection")
      end,
    },
    {
      modes = { "n", "x" },
      key = "[i",
      desc = "Explorer: parent row",
      callback = function()
        invoke("navigate", "parent")
      end,
    },
    {
      modes = { "n", "x" },
      key = "]i",
      desc = "Explorer: last child or sibling",
      callback = function()
        invoke("navigate", "last_child_or_sibling")
      end,
    },
    {
      modes = { "n" },
      key = "h",
      desc = "Explorer: collapse or parent",
      callback = function()
        invoke("collapse")
      end,
    },
    {
      modes = { "n" },
      key = "l",
      desc = "Explorer: expand or open",
      callback = function()
        invoke("activate")
      end,
    },
    {
      modes = { "n" },
      key = "<CR>",
      desc = "Explorer: expand or open",
      callback = function()
        invoke("activate")
      end,
    },
    {
      modes = { "n" },
      key = "<2-LeftMouse>",
      desc = "Explorer: expand or open",
      callback = function()
        invoke("activate")
      end,
    },
    {
      modes = { "n" },
      key = "z",
      desc = "Explorer: recursive expansion",
      callback = function()
        invoke("recursive")
      end,
    },
    {
      modes = { "n" },
      key = "W",
      desc = "Explorer: collapse all",
      callback = function()
        invoke("collapse_all")
      end,
    },
    {
      modes = { "n" },
      key = "<BS>",
      desc = "Explorer: parent root",
      callback = function()
        invoke("root", "parent")
      end,
    },
    {
      modes = { "n" },
      key = ".",
      desc = "Explorer: root at cursor",
      callback = function()
        invoke("root", "cursor")
      end,
    },
    {
      modes = { "n" },
      key = "gb",
      desc = "Explorer: previous root",
      callback = function()
        invoke("root", "previous")
      end,
    },
    {
      modes = { "n" },
      key = "gc",
      desc = "Explorer: cwd",
      callback = function()
        invoke("root", "cwd")
      end,
    },
    {
      modes = { "n" },
      key = "gw",
      desc = "Explorer: workspace",
      callback = function()
        invoke("root", "workspace")
      end,
    },
    {
      modes = { "n" },
      key = "<Tab>",
      desc = "Explorer: toggle selection",
      callback = function()
        invoke("mark", "select")
      end,
    },
    {
      modes = { "x" },
      key = "<Tab>",
      desc = "Explorer: toggle range selection",
      callback = function()
        invoke("mark", "toggle")
      end,
    },
    {
      modes = { "n" },
      key = "c",
      desc = "Explorer: mark copy or copy to path",
      callback = function()
        invoke("transfer", "copy")
      end,
    },
    {
      modes = { "n" },
      key = "x",
      desc = "Explorer: mark move or move to path",
      callback = function()
        invoke("transfer", "cut")
      end,
    },
    {
      modes = { "x" },
      key = "c",
      aliases = { "y" },
      desc = "Explorer: add range to copy selection",
      callback = function()
        invoke("mark", "copy")
      end,
    },
    {
      modes = { "x" },
      key = "x",
      desc = "Explorer: add range to move selection",
      callback = function()
        invoke("mark", "cut")
      end,
    },
    {
      modes = { "n" },
      key = "mc",
      aliases = { "y" },
      desc = "Explorer: mark for copy",
      callback = function()
        invoke("mark", "copy")
      end,
    },
    {
      modes = { "n" },
      key = "mx",
      desc = "Explorer: mark for move",
      callback = function()
        invoke("mark", "cut")
      end,
    },
    {
      modes = { "n" },
      key = "ms",
      desc = "Explorer: mark for selection",
      callback = function()
        invoke("mark", "select")
      end,
    },
    {
      modes = { "n" },
      key = "p",
      desc = "Explorer: paste selection",
      callback = function()
        invoke("operate", { kind = "paste" })
      end,
    },
    {
      modes = { "n", "x" },
      key = "d",
      desc = "Explorer: delete",
      callback = function()
        invoke("delete")
      end,
    },
    {
      modes = { "n" },
      key = "r",
      desc = "Explorer: rename",
      callback = function()
        invoke("operate", { kind = "rename" })
      end,
    },
    {
      modes = { "n" },
      key = "a",
      desc = "Explorer: new file or directory",
      callback = function()
        invoke("create", false)
      end,
    },
    {
      modes = { "n" },
      key = "A",
      desc = "Explorer: new directory",
      callback = function()
        invoke("create", true)
      end,
    },
    {
      modes = { "n" },
      key = "o<CR>",
      desc = "Explorer: open selection",
      callback = function()
        invoke("open")
      end,
    },
    {
      modes = { "n" },
      key = "w",
      desc = "Explorer: open in chosen window",
      callback = function()
        invoke("open", "pick")
      end,
    },
    {
      modes = { "n" },
      key = "J",
      desc = "Explorer: horizontal split",
      callback = function()
        invoke("open", "split")
      end,
    },
    {
      modes = { "n" },
      key = "L",
      desc = "Explorer: vertical split",
      callback = function()
        invoke("open", "vsplit")
      end,
    },
    {
      modes = { "n" },
      key = "<C-x>",
      desc = "Explorer: horizontal split",
      callback = function()
        invoke("open", "split")
      end,
    },
    {
      modes = { "n" },
      key = "<C-v>",
      desc = "Explorer: vertical split",
      callback = function()
        invoke("open", "vsplit")
      end,
    },
    {
      modes = { "n" },
      key = "<C-t>",
      desc = "Explorer: new tab",
      callback = function()
        invoke("open", "tab")
      end,
    },
    {
      modes = { "n" },
      key = "of",
      desc = "Explorer: find files",
      callback = function()
        invoke("auxiliary", "find")
      end,
    },
    {
      modes = { "n" },
      key = "os",
      desc = "Explorer: search content",
      callback = function()
        invoke("auxiliary", "search")
      end,
    },
    {
      modes = { "n" },
      key = "oe",
      desc = "Explorer: directory browser",
      callback = function()
        invoke("auxiliary", "directory")
      end,
    },
    {
      modes = { "n" },
      key = "oc",
      desc = "Explorer: copy paths",
      callback = function()
        invoke("auxiliary", "copy_path")
      end,
    },
    {
      modes = { "n" },
      key = "oi",
      desc = "Explorer: file info",
      callback = function()
        invoke("auxiliary", "info")
      end,
    },
    {
      modes = { "n", "x" },
      key = "oa",
      desc = "Explorer: add locations to AI",
      callback = function()
        invoke("auxiliary", "ai")
      end,
    },
    {
      modes = { "n" },
      key = "oo",
      desc = "Explorer: system open",
      callback = function()
        invoke("auxiliary", "system")
      end,
    },
    {
      modes = { "n" },
      key = "O",
      desc = "Explorer: system open",
      callback = function()
        invoke("auxiliary", "system")
      end,
    },
    {
      modes = { "n" },
      key = "<C-q>",
      desc = "Explorer: quickfix",
      callback = function()
        invoke("auxiliary", "quickfix")
      end,
    },
    {
      modes = { "n" },
      key = "<Space>",
      nowait = false,
      desc = "Explorer: actions and tasks",
      callback = function()
        invoke("menu")
      end,
    },
    { modes = { "n" }, key = "i", desc = "Explorer: read only", callback = function() end },
    { modes = { "n" }, key = "I", desc = "Explorer: read only", callback = function() end },
    {
      modes = { "n" },
      key = "H",
      desc = "Explorer: hidden files",
      callback = function()
        widget:toggle_flag(4)
      end,
    },
  }
  for index, desc in ipairs({
    "Explorer: toggle selected-only view",
    "Explorer: switch Tree/List view",
    "Explorer: toggle directory compression",
    "Explorer: toggle hidden files",
  }) do
    keymaps[#keymaps + 1] = {
      modes = { "n" },
      key = "t" .. index,
      desc = desc,
      callback = function()
        widget:toggle_flag(index)
      end,
    }
  end
  for _, key in ipairs({ "R", "<C-a>r", "<D-r>", "<M-r>" }) do
    keymaps[#keymaps + 1] = {
      modes = { "n" },
      key = key,
      desc = "Explorer: refresh",
      callback = function()
        widget:refresh()
      end,
    }
  end
  for key, kind in pairs({ d = "diagnostic", e = "error", w = "warning", h = "git" }) do
    for _, forward in ipairs({ false, true }) do
      keymaps[#keymaps + 1] = {
        modes = { "n" },
        key = (forward and "]" or "[") .. key,
        desc = "Explorer: " .. (forward and "next " or "previous ") .. kind,
        callback = function()
          invoke("annotation", kind, forward)
        end,
      }
    end
  end
  vim.list_extend(keymaps, dot.state.widget.get_keymaps(widget))
  keymaps[#keymaps + 1] = {
    modes = { "n" },
    key = "?",
    desc = "Explorer: keymap help",
    callback = function()
      local help = {} ---@type stl.t.IKeymap[]
      local entries = {} ---@type table<string, stl.t.IKeymap>
      for _, mode in ipairs({ "n", "x" }) do
        for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(view.bufnr, mode)) do
          -- Which-key installs synthetic prefix mappings alongside the actual actions.
          if mapping.desc and mapping.desc ~= "" and mapping.desc ~= "wk-trigger" then
            local key = vim.fn.keytrans(vim.keycode(mapping.lhs))
            local desc = mapping.desc:gsub("^Explorer:%s*", ""):gsub("^Treeview:?%s+", "")
            local id = key .. "\0" .. desc
            local entry = entries[id]
            if entry then
              entry.modes[#entry.modes + 1] = mode
            else
              entry = {
                modes = { mode },
                key = key,
                desc = desc,
                callback = mapping.callback or mapping.rhs,
              }
              entries[id] = entry
              help[#help + 1] = entry
            end
          end
        end
      end
      table.sort(help, function(left, right)
        return left.key < right.key or left.key == right.key and table.concat(left.modes) < table.concat(right.modes)
      end)
      require("era.view.keysheet").new({ title = "Explorer", keymaps = help }):open()
    end,
  }
  for _, keymap in ipairs(keymaps) do
    if keymap.nowait == nil then
      keymap.nowait = true
    end
  end
  stl.nvim.fn.bindkeys(keymaps, { bufnr = view.bufnr, noremap = true, silent = true })
end

return M
