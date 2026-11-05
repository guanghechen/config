---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.fixtures.ark.keymap_owners" ---@type string

-- Runs in a child Neovim that starts the full configuration: `install` from --cmd, before the configuration loads,
-- and `run` from -c. It records every mapping made while the configuration starts, loads its lazy parts, enters Insert
-- and Command-line mode once, then writes which sources mapped the same key and which mapped keys start longer ones.

local SOURCE = debug.getinfo(1, "S").source ---@type string
local ROOT = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(SOURCE:sub(2))))) ---@type string
local CONFIG = vim.fn.stdpath("config") --[[@as string]]

---@class __test__.fixtures.ark.keymap_owners.IEvent
---@field public op                     "set"|"del"
---@field public key                    string Mode and lhs as Neovim stores the mapping, e.g. "i <CR>".
---@field public bufnr                  integer|false
---@field public source                 string Chunk of the first caller outside the mapping helpers.

local events = {} ---@type __test__.fixtures.ark.keymap_owners.IEvent[]
local defaults = {} ---@type table<string, true>
local nested = 0 ---@type integer

-- Helpers that map on behalf of their caller, which owns the mapping.
local HELPERS = { [SOURCE] = true, ["vim/keymap"] = true } ---@type table<string, true>
for _, prefix in ipairs({ CONFIG, ROOT }) do
  for _, helper in ipairs({ "stl/nvim/fn.lua", "dot/command.lua" }) do
    HELPERS["@" .. prefix .. "/lua/" .. helper] = true
  end
end

local MODES = { [""] = { "n", "x", "s", "o" }, v = { "x", "s" }, ["!"] = { "i", "c" } } ---@type table<string, string[]>

---@return string
local function caller()
  for level = 2, 60 do
    local info = debug.getinfo(level, "S")
    if info == nil then
      break
    end
    if info.what ~= "C" and not HELPERS[info.source] then
      return info.source
    end
  end
  return "?"
end

---@param mode                          string
---@param lhs                           string
---@param bufnr                         integer|false
---@return string
local function key_of(mode, lhs, bufnr)
  -- Neovim's stored lhs keeps <C-I>/<Tab> and <C-[>/<Esc> apart and expands <Leader>; vim.keycode() does neither.
  local function lookup()
    return vim.fn.maparg(lhs, mode, false, true).lhsraw
  end
  local raw ---@type string|nil
  if bufnr and bufnr ~= vim.api.nvim_get_current_buf() and vim.api.nvim_buf_is_valid(bufnr) then
    raw = vim.api.nvim_buf_call(bufnr, lookup)
  else
    raw = lookup()
  end
  return mode .. " " .. vim.fn.keytrans(raw or vim.keycode(lhs))
end

---@param op                            "set"|"del"
---@param modes                         string|string[]
---@param lhs                           string
---@param bufnr                         integer|false
---@return nil
local function record(op, modes, lhs, bufnr)
  local source = caller()
  for _, mode in ipairs(type(modes) == "table" and modes or { modes }) do
    for _, expanded in ipairs(MODES[mode] or { mode }) do
      events[#events + 1] = { op = op, key = key_of(expanded, lhs, bufnr), bufnr = bufnr, source = source }
    end
  end
end

---@param buffer                        integer|boolean|nil
---@return integer|false
local function bufnr_of(buffer)
  if buffer == true or buffer == 0 then
    return vim.api.nvim_get_current_buf()
  end
  return type(buffer) == "number" and buffer or false
end

local M = {}

---@return nil
function M.install()
  for _, mode in ipairs({ "n", "x", "s", "o", "i", "c", "t" }) do
    for _, map in ipairs(vim.api.nvim_get_keymap(mode)) do
      defaults[mode .. " " .. vim.fn.keytrans(map.lhsraw)] = true
    end
  end

  -- Machine-local overrides are not part of the checkout, and language servers are not needed for mappings.
  for _, name in ipairs({ "autocmd", "option", "keymap", "plugin", "dressing" }) do
    package.preload["ark.vendor.local." .. name] = function()
      return {}
    end
  end
  vim.lsp.start = function()
    return nil
  end

  local set, del = vim.keymap.set, vim.keymap.del
  vim.keymap.set = function(modes, lhs, rhs, opts)
    nested = nested + 1
    local ok, err = pcall(set, modes, lhs, rhs, opts)
    nested = nested - 1
    assert(ok, err)
    record("set", modes, lhs, bufnr_of(opts and (opts.buf or opts.buffer)))
  end
  vim.keymap.del = function(modes, lhs, opts)
    record("del", modes, lhs, bufnr_of(opts and (opts.buf or opts.buffer)))
    nested = nested + 1
    local ok, err = pcall(del, modes, lhs, opts)
    nested = nested - 1
    assert(ok, err)
  end

  local api = vim.api
  local set_keymap, buf_set_keymap = api.nvim_set_keymap, api.nvim_buf_set_keymap
  local del_keymap, buf_del_keymap = api.nvim_del_keymap, api.nvim_buf_del_keymap
  api.nvim_set_keymap = function(mode, lhs, rhs, opts)
    set_keymap(mode, lhs, rhs, opts)
    if nested == 0 then
      record("set", mode, lhs, false)
    end
  end
  api.nvim_buf_set_keymap = function(buffer, mode, lhs, rhs, opts)
    buf_set_keymap(buffer, mode, lhs, rhs, opts)
    if nested == 0 then
      record("set", mode, lhs, bufnr_of(buffer))
    end
  end
  api.nvim_del_keymap = function(mode, lhs)
    if nested == 0 then
      record("del", mode, lhs, false)
    end
    del_keymap(mode, lhs)
  end
  api.nvim_buf_del_keymap = function(buffer, mode, lhs)
    if nested == 0 then
      record("del", mode, lhs, bufnr_of(buffer))
    end
    buf_del_keymap(buffer, mode, lhs)
  end
end

---@param source                        string
---@return string
local function owner_of(source)
  if source:sub(1, 1) ~= "@" then
    return "nvim" -- Chunks compiled into Neovim, such as vim/_core/defaults.
  end
  local path = source:sub(2)
  for _, prefix in ipairs({ CONFIG .. "/lua/", ROOT .. "/lua/" }) do
    if vim.startswith(path, prefix) then
      return path:sub(#prefix + 1)
    end
  end
  local plugin_root = require("era.m.plugin.state").options.root .. "/"
  if vim.startswith(path, plugin_root) then
    return "plugin:" .. path:sub(#plugin_root + 1):match("^[^/]+")
  end
  if vim.startswith(path, vim.env.VIMRUNTIME .. "/") then
    return "nvim"
  end
  return path
end

---@param out_path                      string
---@return nil
local function report(out_path)
  local missing = {} ---@type string[]
  for name, plugin in pairs(require("era.m.plugin.loader").plugins) do
    if plugin.spec.enabled ~= false and plugin.path ~= nil and vim.uv.fs_stat(plugin.path) == nil then
      missing[#missing + 1] = name
    end
  end
  if #missing > 0 then
    table.sort(missing)
    vim.fn.writefile({ vim.json.encode({ missing = missing }) }, out_path)
    return
  end

  -- Insert mode must not switch the host's input source.
  dot.context.behavior.auto_im:next(false)
  vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy", modeline = false })
  vim.wait(100) -- Drains callbacks the lazy plugins schedule.
  vim.api.nvim_feedkeys(vim.keycode("i<Esc>:<Esc>"), "x", false)
  vim.wait(100)

  local chains = {} ---@type table<string, string[]>
  local global_owner = {} ---@type table<string, string>
  local buffer_owner = {} ---@type table<string, string>
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  for _, event in ipairs(events) do
    local owner = owner_of(event.source)
    if event.bufnr == false then
      local chain = chains[event.key] or (defaults[event.key] and { "nvim" } or {})
      local step = (event.op == "del" and "-" or "") .. owner
      if chain[#chain] ~= step then
        chain[#chain + 1] = step
      end
      chains[event.key] = chain
      global_owner[event.key] = event.op == "set" and owner or nil
    elseif event.bufnr == bufnr and event.op == "set" then
      buffer_owner[event.key] = owner
    end
  end

  local overrides = {} ---@type table<string, string>
  for key, chain in pairs(chains) do
    if #chain >= 2 then
      overrides[key] = table.concat(chain, " -> ")
    end
  end

  local shadows = {} ---@type table<string, string>
  for _, mode in ipairs({ "n", "x", "s", "o", "i", "c" }) do
    local globals = {} ---@type table<string, true>
    for _, map in ipairs(vim.api.nvim_get_keymap(mode)) do
      globals[mode .. " " .. vim.fn.keytrans(map.lhsraw)] = true
    end
    for _, map in ipairs(vim.api.nvim_buf_get_keymap(bufnr, mode)) do
      local key = mode .. " " .. vim.fn.keytrans(map.lhsraw)
      if globals[key] then
        shadows[key] = (global_owner[key] or (defaults[key] and "nvim") or "?") .. " -> " .. (buffer_owner[key] or "?")
      end
    end
  end

  -- Mapped keys that start a longer mapping without nowait; which-key waits for the key after them.
  local prefixes = {} ---@type table<string, string>
  for _, mode in ipairs({ "n", "x" }) do
    local maps = {} ---@type table<string, table>
    for _, map in ipairs(vim.api.nvim_get_keymap(mode)) do
      maps[map.lhsraw] = map
    end
    for _, map in ipairs(vim.api.nvim_buf_get_keymap(bufnr, mode)) do
      maps[map.lhsraw] = map
    end
    local lhss = vim.tbl_keys(maps) ---@type string[]
    table.sort(lhss)
    -- Sorted, the mappings a key starts follow it directly.
    for index, lhs in ipairs(lhss) do
      local following = lhss[index + 1]
      if maps[lhs].nowait ~= 1 and following ~= nil and vim.startswith(following, lhs) then
        local key = mode .. " " .. vim.fn.keytrans(lhs)
        local owner = maps[lhs].buffer ~= 0 and buffer_owner[key] or global_owner[key]
        prefixes[key] = owner or (defaults[key] and "nvim") or "?"
      end
    end
  end

  -- Select mode types a printable key over the selection, so a map that starts with one takes the key instead.
  local typed = {} ---@type table<string, string>
  for _, map in ipairs(vim.list_extend(vim.api.nvim_get_keymap("s"), vim.api.nvim_buf_get_keymap(bufnr, "s"))) do
    local byte = map.lhsraw:byte(1) ---@type integer|nil
    if byte ~= nil and ((byte >= 0x20 and byte < 0x7f) or byte >= 0xc2) then
      local key = "s " .. vim.fn.keytrans(map.lhsraw)
      typed[key] = (map.buffer ~= 0 and buffer_owner[key] or global_owner[key]) or (defaults[key] and "nvim") or "?"
    end
  end

  vim.fn.writefile(
    { vim.json.encode({ overrides = overrides, shadows = shadows, prefixes = prefixes, typed = typed }) },
    out_path
  )
end

---@param out_path                      string
---@return nil
function M.run(out_path)
  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
      -- After the startup work the configuration schedules, as with a UI, where VeryLazy follows UIEnter.
      vim.schedule(function()
        local ok, err = pcall(report, out_path)
        if not ok then
          vim.fn.writefile({ vim.json.encode({ error = tostring(err) }) }, out_path)
        end
        vim.cmd("qa!")
      end)
    end,
  })
end

return M
