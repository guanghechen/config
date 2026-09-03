---@diagnostic disable: undefined-global

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.cmp.keymap")
local bound = {} ---@type stl.t.IKeymap[]

bootstrap.with_stl(t, {
  nvim = {
    fn = {
      bindkeys = function(keymaps)
        bound = keymaps
      end,
    },
  },
})

local Keymap = require("era.m.cmp.keymap")

local function get(key)
  return assert(
    vim.iter(bound):find(function(item)
      return item.key == key
    end),
    "missing keymap: " .. key
  )
end

local function install(bufnr)
  for _, item in ipairs(bound) do
    vim.keymap.set(item.modes, item.key, item.callback, { buffer = bufnr })
  end
end

local function set_actions(overrides)
  local value = {
    accept = function()
      return false
    end,
    backspace = function() end,
    cancel = function()
      return false
    end,
    move = function()
      return false
    end,
    signature = function()
      return false
    end,
    show = function() end,
    visible = function()
      return false
    end,
  }
  Keymap.set_actions(vim.tbl_extend("force", value, overrides or {}))
end

t:test("insert navigation delegates to the controller", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  bound = {}
  local moves = {} ---@type integer[]
  set_actions({
    move = function(value, direction)
      t.assert_eq(bufnr, value, "buffer")
      moves[#moves + 1] = direction
      return true
    end,
  })

  Keymap.bind(bufnr)
  get("<Tab>").callback()
  get("<S-Tab>").callback()
  get("<Down>").callback()
  get("<Up>").callback()

  t.assert_eq(1, moves[1], "tab")
  t.assert_eq(-1, moves[2], "shift tab")
  t.assert_eq(1, moves[3], "down")
  t.assert_eq(-1, moves[4], "up")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("acceptance delegates synchronously with numeric indices", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  bound = {}
  local accepted = {} ---@type integer[]
  set_actions({
    accept = function(value, index)
      t.assert_eq(bufnr, value, "buffer")
      accepted[#accepted + 1] = index or 0
      return true
    end,
  })

  Keymap.bind(bufnr)
  get("<CR>").callback()
  get("<C-y>").callback()
  get("<C-1>").callback()
  get("<C-9>").callback()

  t.assert_eq(0, accepted[1], "enter")
  t.assert_eq(0, accepted[2], "control y")
  t.assert_eq(1, accepted[3], "first item")
  t.assert_eq(9, accepted[4], "ninth item")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("backspace prepares controller state before invoking its fallback", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  bound = {}
  local events = {} ---@type string[]
  set_actions({
    backspace = function()
      events[#events + 1] = "prepare"
    end,
  })
  t:patch_table(vim.api, "nvim_feedkeys", function()
    events[#events + 1] = "fallback"
  end)

  Keymap.bind(bufnr)
  get("<BS>").callback()

  t.assert_eq("prepare", events[1], "prepare")
  t.assert_eq("fallback", events[2], "delete")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("documentation controls use the owned popup", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  bound = {}
  local toggles = 0
  local directions = {} ---@type integer[]
  t:patch_table(package.loaded, "era.m.ui_attach.popupmenu", {
    toggle_documentation = function()
      toggles = toggles + 1
      return true
    end,
    scroll_documentation = function(direction)
      directions[#directions + 1] = direction
      return true
    end,
  })
  set_actions({
    visible = function()
      return true
    end,
  })

  Keymap.bind(bufnr)
  get("<C-space>").callback()
  get("<C-b>").callback()
  get("<C-f>").callback()

  t.assert_eq(1, toggles, "toggle")
  t.assert_eq(-1, directions[1], "scroll up")
  t.assert_eq(1, directions[2], "scroll down")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("hidden controller actions preserve original mapping fallbacks", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  local calls = 0
  vim.keymap.set("i", "<C-j>", function()
    calls = calls + 1
  end, { buffer = bufnr })
  bound = {}
  set_actions()

  Keymap.bind(bufnr)
  get("<C-j>").callback()
  t.assert_eq(1, calls, "fallback callback")

  Keymap.unbind(bufnr)
  local restored
  vim.api.nvim_buf_call(bufnr, function()
    restored = vim.fn.maparg("<C-j>", "i", false, true)
  end)
  t.assert_eq("function", type(restored.callback), "restored callback")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("unbind preserves mappings installed after completion", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  bound = {}
  set_actions()
  Keymap.bind(bufnr)
  install(bufnr)
  local replacement = function() end
  vim.keymap.set("i", "<C-j>", replacement, { buffer = bufnr })

  Keymap.unbind(bufnr)
  local current
  vim.api.nvim_buf_call(bufnr, function()
    current = vim.fn.maparg("<C-j>", "i", false, true)
  end)
  t.assert_eq(replacement, current.callback, "replacement mapping")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("release drops invalid-buffer ownership without buffer access", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  bound = {}
  set_actions()
  Keymap.bind(bufnr)
  vim.api.nvim_buf_delete(bufnr, { force = true })

  t.assert_true(Keymap.release(bufnr), "owned state")
  t.assert_false(Keymap.release(bufnr), "released state")
end)

t:test("signature help falls back without a provider", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  bound = {}
  set_actions()
  local fed
  t:patch_table(vim.api, "nvim_feedkeys", function(keys)
    fed = keys
  end)

  Keymap.bind(bufnr)
  get("<C-p>").callback()
  t.assert_eq(vim.keycode("<C-p>"), fed, "signature fallback")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("cmdline mappings delegate to their controller", function()
  bound = {}
  local moves = {} ---@type integer[]
  local accepted = 0
  local cancelled = 0
  Keymap.set_cmdline_actions({
    accept = function()
      accepted = accepted + 1
      return true
    end,
    cancel = function()
      cancelled = cancelled + 1
      return true
    end,
    move = function(direction)
      moves[#moves + 1] = direction
      return true
    end,
    show = function(direction)
      moves[#moves + 1] = direction
      return true
    end,
  })

  Keymap.bind_cmdline()
  get("<Tab>").callback()
  get("<S-Tab>").callback()
  get("<C-y>").callback()
  get("<C-e>").callback()

  t.assert_eq(1, moves[1], "next")
  t.assert_eq(-1, moves[2], "previous")
  t.assert_eq(1, accepted, "accept")
  t.assert_eq(1, cancelled, "cancel")
end)

t:run()
