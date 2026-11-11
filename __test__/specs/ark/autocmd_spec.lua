local bootstrap = require("__test__.support.bootstrap")
local fs = require("__test__.support.fs")
local harness = require("__test__.support.harness")

local t = harness.new()

---@class ark.autocmd.test.IRuntime
---@field autocmds                      table<string, table>
---@field autocmd_events                table<string, string|string[]>
---@field schedule                      __test__.support.bootstrap.ISchedule
---@field bufnr                         integer
---@field winnr                         integer
---@field valid                         boolean
---@field cursor_updates                integer
---@field accepted                      integer
---@field cursor_error                  boolean

---Records the autocmds created from now on by group in `autocmds`, and their events in `events`, instead of creating
---them.
---@param autocmds                      table<string, table>
---@param events                        table<string, string|string[]>
---@return nil
local function record_autocmds(autocmds, events)
  t:patch_table(vim.api, "nvim_create_augroup", function(name)
    return name
  end)
  t:patch_table(vim.api, "nvim_create_autocmd", function(event, opts)
    autocmds[opts.group] = opts
    events[opts.group] = event
    return 1
  end)
end

---@return ark.autocmd.test.IRuntime
local function setup()
  local runtime = {
    autocmds = {},
    autocmd_events = {},
    schedule = bootstrap.with_schedule(t),
    bufnr = 1,
    winnr = 11,
    valid = true,
    cursor_updates = 0,
    accepted = 0,
    cursor_error = false,
  } ---@type ark.autocmd.test.IRuntime

  t:patch_global("stl", {
    nvim = {
      buf = {
        on_buf_open = function() end,
        on_buf_close = function() end,
      },
    },
  })
  t:patch_global("dot", {})
  t:patch_global("era", {
    dressing = {
      scroll = {
        accept_current_view = function()
          runtime.accepted = runtime.accepted + 1
        end,
      },
    },
    m = {
      python_venv = { dressing = function() end },
    },
  })
  t:patch_global("yoz", {
    path = {
      dirname = function()
        return ""
      end,
      mkdirs = function() end,
    },
  })
  t:patch_table(vim, "b", { [1] = {} })
  t:patch_table(vim.filetype, "add", function() end)
  record_autocmds(runtime.autocmds, runtime.autocmd_events)
  t:patch_table(vim.api, "nvim_get_current_win", function()
    return runtime.winnr
  end)
  t:patch_table(vim.api, "nvim_win_get_buf", function()
    return runtime.bufnr
  end)
  t:patch_table(vim.api, "nvim_win_is_valid", function(winnr)
    return runtime.valid and winnr == runtime.winnr
  end)
  t:patch_table(vim.api, "nvim_buf_get_mark", function()
    return { 20, 3 }
  end)
  t:patch_table(vim.api, "nvim_buf_line_count", function()
    return 100
  end)
  t:patch_table(vim.api, "nvim_win_set_cursor", function()
    if runtime.cursor_error then
      error("cursor update failed")
    end
    runtime.cursor_updates = runtime.cursor_updates + 1
  end)

  assert(loadfile("lua/ark/autocmd.lua"))()
  return runtime
end

---@param runtime                      ark.autocmd.test.IRuntime
---@return nil
local function schedule_last_location(runtime)
  runtime.autocmds.ark_goto_last_location_read.callback({ buf = 1 })
  runtime.autocmds.ark_goto_last_location.callback({ buf = 1 })
  t.assert_eq(1, #runtime.schedule.callbacks, "scheduled callbacks")
end

t:test("accepts the restored cursor position as the scroll baseline", function()
  local runtime = setup()
  schedule_last_location(runtime)

  runtime.schedule.drain()

  t.assert_eq(1, runtime.cursor_updates, "cursor updates")
  t.assert_eq(1, runtime.accepted, "accepted views")
end)

t:test("a window that disappears before restoration does not consume the saved cursor", function()
  local runtime = setup()
  schedule_last_location(runtime)
  runtime.valid = false
  runtime.schedule.drain()
  t.assert_eq(0, runtime.accepted, "expired window has no scroll baseline")
  t.assert_false(vim.b[1].eve_last_loc, "saved cursor remains pending")

  runtime.valid = true
  runtime.winnr = 12
  t.assert_eq("BufWinEnter", runtime.autocmd_events.ark_goto_last_location, "restore on display")
  schedule_last_location(runtime)
  runtime.schedule.drain()
  t.assert_eq(2, runtime.cursor_updates, "first real display restores the cursor again")
end)

t:test("repeated entry events restore the saved cursor only once", function()
  local runtime = setup()
  schedule_last_location(runtime)
  runtime.autocmds.ark_goto_last_location.callback({ buf = 1 })
  t.assert_eq(1, #runtime.schedule.callbacks, "one pending restoration")
  runtime.schedule.drain()
  t.assert_eq(1, runtime.cursor_updates, "one cursor restoration")
end)

t:test("does not commit restoration when the window changes buffers before the scheduled callback", function()
  local runtime = setup()
  schedule_last_location(runtime)

  runtime.bufnr = 2
  runtime.schedule.drain()

  t.assert_false(vim.b[1].eve_last_loc, "restoration remains pending after the buffer changed")
  t.assert_nil(vim.b[1].eve_last_loc_winnr, "stale window claim released")
  t.assert_eq(0, runtime.accepted, "accepted views")
end)

t:test("does not accept a baseline when restoring the cursor fails", function()
  local runtime = setup()
  runtime.cursor_error = true
  schedule_last_location(runtime)
  runtime.schedule.drain()

  t.assert_eq(0, runtime.cursor_updates, "cursor updates")
  t.assert_eq(0, runtime.accepted, "accepted views")
end)

t:test("refreshes the filepath cache after a buffer rename", function()
  local runtime = setup()
  local events = runtime.autocmd_events.ark_cache_buf_filepath

  t.assert_same({ "BufWinEnter", "BufFilePost" }, events, "cache refresh events")
end)

for _, filetype in ipairs({ "gitcommit", "gitrebase" }) do
  t:test(filetype .. " starts at the top instead of the position saved for its previous content", function()
    local runtime = setup()
    local get_option_value = vim.api.nvim_get_option_value
    t:patch_table(vim.api, "nvim_get_option_value", function(name, opts)
      return name == "filetype" and filetype or get_option_value(name, opts)
    end)

    runtime.autocmds.ark_goto_last_location_read.callback({ buf = 1 })
    runtime.autocmds.ark_goto_last_location.callback({ buf = 1 })
    t.assert_eq(0, #runtime.schedule.callbacks, "scheduled restorations")
    t.assert_eq(0, runtime.cursor_updates, "cursor updates")
  end)
end

t:test("q stays free for recording macros in a commit message", function()
  local runtime = setup()

  t.assert_false(vim.tbl_contains(runtime.autocmds.ark_close_filetypes_with_q.pattern, "gitcommit"))
end)

for _, host in ipairs({ "neovim", "neovide", "vscode", "yozvim", "yuivim" }) do
  t:test(host .. " keeps Python environment setup under the correct owner", function()
    t:patch_table(vim, "g", host == "neovim" and {} or { [host] = true })
    local runtime = setup()
    local expected = host == "neovim" or host == "neovide"
    t.assert_eq(expected, runtime.autocmds.ark_python_venv ~= nil, "Python FileType handler")
  end)
end

---Loads lua/ark/autocmd.lua without registering its autocmds, and returns them by group.
---@return table<string, table>
local function load_autocmds()
  local autocmds = {} ---@type table<string, table>
  record_autocmds(autocmds, {})
  assert(loadfile("lua/ark/autocmd.lua"))()
  return autocmds
end

-- Patterns of equal priority are tried in an order that changes from one process to the next, so each overlap below
-- passed or failed by chance before the configuration stopped competing with Neovim's own patterns.
t:test("filetype patterns match the intended files and leave Neovim's own rules in place", function()
  load_autocmds()

  for filepath, expected in pairs({
    ["/home/user/.config/fzf/fzf.fzfrc"] = "bash",
    ["/home/user/.config/ripgrep/web.tsx.ripgreprc"] = "bash",
    ["/home/user/.config/tmux/conf/keymap.tmux.conf"] = "tmux",
    ["/repo/.vscode/settings.json"] = "jsonc",
    ["/repo/data.json5"] = "json5",
    ["/home/user/.vimrc"] = "vim",
    ["/repo/resource.rc"] = "rc",
    ["/repo/.env"] = "env",
    ["/repo/.env.local"] = "env",
    ["/repo/.env.production"] = "env",
    ["/home/user/.config/kitty/kitty.conf"] = "kitty",
    ["/home/user/.config/kitty/theme.conf"] = "kitty",
    ["/home/user/.config/kitty/current-theme.conf"] = "kitty",
  }) do
    t.assert_eq(expected, (vim.filetype.match({ filename = filepath })), filepath)
  end
end)

t:test("a file over the size limit is a bigfile even where Neovim has a pattern for its path", function()
  load_autocmds()
  t:patch_table(vim.g, "bigfile_size", 8)
  local dir = t:tempdir()

  for _, name in ipairs({ "hypr/big.conf", "kitty/big.conf", "lxqt/big.conf", "project/.env.big" }) do
    local filepath = vim.fs.joinpath(dir, name)
    fs.write(filepath, { "longer than the size limit" })
    local bufnr = vim.fn.bufadd(filepath) ---@type integer
    t:defer(function()
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
    t.assert_eq("bigfile", (vim.filetype.match({ filename = filepath, buf = bufnr })), name)
  end
end)

-- The cases below turn on Neovim's filetype plugins for the rest of the process, so they run last.

---Registers the handler that keeps [[ and ]] after Neovim's filetype plugins, as the configuration's own handlers are,
---and returns a function that gives buffer `bufnr`, a new one by default, a filetype.
---@return fun(filetype: string, bufnr: integer|nil): integer
local function keep_reference_jumps()
  local create_augroup, create_autocmd = vim.api.nvim_create_augroup, vim.api.nvim_create_autocmd
  local handler = assert(load_autocmds().ark_keep_reference_jumps, "the handler")
  vim.cmd("filetype plugin on")
  local group = create_augroup("keep_reference_jumps_spec", { clear = true })
  t:defer(function()
    vim.api.nvim_del_augroup_by_id(group)
  end)
  create_autocmd("FileType", { group = group, callback = handler.callback })
  return function(filetype, bufnr)
    bufnr = bufnr or t:buffer(nil, { listed = true })
    vim.api.nvim_set_option_value("filetype", filetype, { buf = bufnr })
    return bufnr
  end
end

---Global [[ and ]] in Normal and Visual mode, as the configuration maps them: with a Lua callback.
---@return nil
local function map_reference_jumps()
  for _, lhs in ipairs({ "[[", "]]" }) do
    vim.keymap.set({ "n", "x" }, lhs, function() end, { desc = "reference" })
    t:defer(function()
      vim.keymap.del({ "n", "x" }, lhs)
    end)
  end
end

---Who maps `lhs` in `mode` in buffer `bufnr` itself: the description of the map, "runtime" for a map of Neovim's
---filetype plugins without one, or nil.
---@param bufnr                         integer
---@param mode                          string
---@param lhs                           string
---@return string|nil
local function owner(bufnr, mode, lhs)
  for _, keymap in ipairs(vim.api.nvim_buf_get_keymap(bufnr, mode)) do
    if keymap.lhs == lhs then
      return keymap.desc or (keymap.sid > 0 and "runtime" or "?")
    end
  end
end

t:test("Neovim's filetype plugins give [[ and ]] to the global maps in Normal and Visual mode", function()
  map_reference_jumps()
  local filetype = keep_reference_jumps()

  local python = filetype("python")
  t.assert_eq("reference", owner(python, "n", "[["), "python, Normal")
  t.assert_eq("reference", owner(python, "x", "]]"), "python, Visual")
  t.assert_eq("runtime", owner(python, "o", "]]"), "python, Operator-pending")
  -- One :noremap covers Normal, Visual and Operator-pending mode.
  local go = filetype("go")
  t.assert_eq("reference", owner(go, "n", "]]"), "go, Normal")
  t.assert_eq("reference", owner(go, "x", "[["), "go, Visual")
  t.assert_eq("runtime", owner(go, "o", "[["), "go, Operator-pending")
  t.assert_eq("reference", owner(filetype("markdown"), "n", "]]"), "markdown, mapped from Lua")

  local panel = t:buffer()
  vim.keymap.set("n", "[[", function() end, { buf = panel, desc = "page" })
  t.assert_eq("page", owner(filetype("diffview-commits", panel), "n", "[["), "a map of the configuration's own")
end)

t:test("a filetype plugin still undoes [[ and ]] after they give way to the global maps", function()
  map_reference_jumps()
  local filetype = keep_reference_jumps()

  -- Their undo unmaps [[ without `silent!`, which fails on a map that is gone.
  for _, name in ipairs({ "gdscript", "abaqus" }) do
    local bufnr = filetype(name)
    t.assert_eq("reference", owner(bufnr, "n", "[["), name)
    filetype("text", bufnr)
    t.assert_nil(owner(bufnr, "n", "[["), name .. " undone")
  end
end)

t:test("without global [[ and ]], filetype plugins keep their own", function()
  local filetype = keep_reference_jumps()

  local python = filetype("python")
  t.assert_eq("runtime", owner(python, "n", "[["))
  local rhs = vim.api.nvim_buf_call(python, function()
    return vim.fn.maparg("[[", "n")
  end)
  t.assert_true(rhs:find("Python_jump", 1, true) ~= nil, "the map as the ftplugin set it: " .. rhs)
end)

-- This case leaves the filetype plugin's settings in the current buffer, so it runs last.
t:test("FileType for a buffer other than the current one gives way where the filetype plugin maps", function()
  map_reference_jumps()
  local filetype = keep_reference_jumps()
  local other = filetype("python")
  local current = vim.api.nvim_get_current_buf()

  -- Neovim's filetype plugins then map in the current buffer, as for notepad's call.
  vim.api.nvim_exec_autocmds("FileType", { buf = other })
  t.assert_eq("reference", owner(current, "n", "[["), "the current buffer")
  t.assert_eq("reference", owner(other, "n", "[["), "the event's buffer")
end)

t:run()
