---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.pairs.child" ---@type string

-- Child side of the pairs benchmark, loaded in a UI child after the ark bootstrap. A variant installs one pairs
-- implementation; the measurements time it in this process and return milliseconds.

local hrtime = vim.uv.hrtime

local M = {
  provider_ns = 0,
  bufnr = 0,
  winnr = 0,
}

---@class __test__.bench.pairs.child.IVariant
---@field namespaces                    string[] Decoration provider namespaces whose callbacks are timed.
---@field setup                         fun(arg: any): nil
---@field parse                         ?fun(bufnr: integer): nil A full parse of the buffer.
---@field attach                        ?fun(bufnr: integer): nil Starts incremental tracking of the buffer.
---@field matchparen                    ?fun(): fun() The callback that runs when the cursor moves.

---@type table<string, __test__.bench.pairs.child.IVariant>
local variants = {
  none = {
    namespaces = {},
    setup = function() end,
  },
  blink = {
    namespaces = { "blink.pairs" },
    setup = function(root)
      require("__test__.support.blink_pairs").setup(root)
    end,
    parse = function(bufnr)
      local rust = require("blink.pairs.rust")
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local tab_width = require("blink.pairs.utils").get_tab_width(bufnr)
      -- A fixed id outside real buffer numbers: the first call parses, later calls reparse the whole range.
      assert(rust.parse_buffer(1000000, tab_width, vim.bo[bufnr].filetype, lines), "blink.pairs did not parse")
    end,
    attach = function(bufnr)
      assert(require("blink.pairs.watcher").attach(bufnr), "blink.pairs did not attach")
    end,
    matchparen = function()
      local autocmds = vim.api.nvim_get_autocmds({ group = "BlinkPairsMatchparen", event = "CursorMoved" })
      local callback = assert(autocmds[1] and autocmds[1].callback, "no blink.pairs matchparen autocmd")
      return function()
        callback({ event = "CursorMoved", buf = M.bufnr })
      end
    end,
  },
  era = {
    namespaces = { "era.dressing.pairs" },
    setup = function()
      era.dressing.pairs.dressing()
      era.keystroke.pairs.setup()
    end,
    parse = function(bufnr)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local language = assert(era.m.pairs.language_of(vim.bo[bufnr].filetype), "no pairs language")
      local document = yoz.pairs.new(language, 4)
      document:edit(0, 0, lines)
      -- A query pairs the tokens, which blink.pairs' parse also does.
      document:highlights(0, 0, 0, 0)
    end,
    attach = function(bufnr)
      assert(era.m.pairs.document(bufnr), "era.m.pairs did not attach")
    end,
    matchparen = function()
      local callback ---@type function|nil
      for _, autocmd in ipairs(vim.api.nvim_get_autocmds({ event = "CursorMoved" })) do
        if autocmd.group_name == "guanghechen_era.dressing.pairs" then
          callback = autocmd.callback
        end
      end
      assert(callback, "no era.dressing.pairs matchparen autocmd")
      return function()
        callback({ event = "CursorMoved", buf = M.bufnr })
      end
    end,
  },
}

M.variant = variants.none

---Wraps the decoration providers of `names` registered from now on, adding their time to `M.provider_ns`.
---@param names                         string[]
---@return nil
local function time_providers(names)
  local timed = {} ---@type table<string, boolean>
  for _, name in ipairs(names) do
    timed[name] = true
  end
  local register = vim.api.nvim_set_decoration_provider
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.api.nvim_set_decoration_provider = function(namespace, callbacks)
    local name ---@type string|nil
    for key, id in pairs(vim.api.nvim_get_namespaces()) do
      if id == namespace then
        name = key
      end
    end
    if name and timed[name] then
      for _, event in ipairs({ "on_start", "on_buf", "on_win", "on_line", "on_range", "on_end" }) do
        local callback = callbacks[event]
        if callback then
          callbacks[event] = function(...)
            local started = hrtime()
            local a, b = callback(...)
            M.provider_ns = M.provider_ns + hrtime() - started
            return a, b
          end
        end
      end
    end
    return register(namespace, callbacks)
  end
end

---@param name                          string
---@param arg                           any
---@param parser_dir                    ?string Treesitter parsers for the rules that query a syntax tree.
---@return nil
function M.setup(name, arg, parser_dir)
  M.variant = assert(variants[name], "unknown variant " .. name)
  -- `-u NONE` skips the filetype detection and plugins that a normal startup enables.
  vim.cmd("filetype plugin indent on")
  if parser_dir and vim.uv.fs_stat(parser_dir) then
    vim.opt.runtimepath:append(parser_dir)
  end
  time_providers(M.variant.namespaces)
  M.variant.setup(arg)
end

---Opens `path` in the current window with the cursor on `row` (0-based) at the center.
---@param path                          string
---@param row                           integer
---@return string filetype
---@return number elapsed Milliseconds to open, attach and draw the window.
function M.open(path, row)
  local started = hrtime()
  vim.cmd.edit(vim.fn.fnameescape(path))
  M.bufnr, M.winnr = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_cursor(M.winnr, { row + 1, 0 })
  vim.cmd("normal! zz")
  if M.variant.attach then
    M.variant.attach(M.bufnr)
  end
  vim.api.nvim__redraw({ win = M.winnr, valid = false, flush = true })
  return vim.bo[M.bufnr].filetype, (hrtime() - started) / 1e6
end

---@param warmups                       integer
---@param iterations                    integer
---@param sample                        fun(index: integer): number|nil
---@return number[]
local function collect(warmups, iterations, sample)
  local samples = {} ---@type number[]
  for index = 1, warmups + iterations do
    local value = sample(index)
    if index > warmups and value then
      samples[#samples + 1] = value
    end
  end
  return samples
end

---@param iterations                    integer
---@return number[]|nil
function M.parse(iterations)
  local parse = M.variant.parse
  if not parse then
    return nil
  end
  return collect(2, iterations, function()
    local started = hrtime()
    parse(M.bufnr)
    return (hrtime() - started) / 1e6
  end)
end

---@param kind                          "char"|"pair"|"open"|"line"
---@param row                           integer
---@param col                           integer
---@return fun(), fun()
local function edit_pair(kind, row, col)
  local bufnr = M.bufnr
  if kind == "line" then
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, true)
    return function()
      vim.api.nvim_buf_set_lines(bufnr, row, row + 1, true, {})
    end, function()
      vim.api.nvim_buf_set_lines(bufnr, row, row, true, line)
    end
  end
  local text = kind == "char" and "x" or kind == "pair" and "()" or "("
  return function()
    vim.api.nvim_buf_set_text(bufnr, row, col, row, col, { text })
  end, function()
    vim.api.nvim_buf_set_text(bufnr, row, col, row, col + #text, { "" })
  end
end

---Times an edit and its revert, each including the variant's synchronous change tracking.
---@param kind                          "char"|"pair"|"open"|"line"
---@param row                           integer
---@param col                           integer
---@param iterations                    integer
---@return { edit: number[], revert: number[] }
function M.edit(kind, row, col, iterations)
  local apply, revert = edit_pair(kind, row, col)
  local reverts = {} ---@type number[]
  local edits = collect(5, iterations, function(index)
    local started = hrtime()
    apply()
    local applied = hrtime()
    revert()
    if index > 5 then
      reverts[#reverts + 1] = (hrtime() - applied) / 1e6
    end
    return (applied - started) / 1e6
  end)
  return { edit = edits, revert = reverts }
end

---@return number redraw
---@return number provider
local function redraw()
  M.provider_ns = 0
  local started = hrtime()
  vim.api.nvim__redraw({ win = M.winnr, valid = false, flush = true })
  return (hrtime() - started) / 1e6, M.provider_ns / 1e6
end

---Forced redraws of the whole window: unchanged, after a one-character edit, and after scrolling a page.
---@param mode                          "static"|"edit"|"scroll"
---@param row                           integer
---@param col                           integer
---@param iterations                    integer
---@return { redraw: number[], provider: number[] }
function M.redraw(mode, row, col, iterations)
  local providers = {} ---@type number[]
  local apply, revert = edit_pair("char", row, col)
  local height = vim.api.nvim_win_get_height(M.winnr)
  local count = vim.api.nvim_buf_line_count(M.bufnr)
  local top = vim.fn.line("w0", M.winnr)
  local redraws = collect(10, iterations, function(index)
    if mode == "edit" then
      if index % 2 == 1 then
        apply()
      else
        revert()
      end
    elseif mode == "scroll" then
      top = top + height
      if top + height > count then
        top = 1
      end
      vim.api.nvim_win_call(M.winnr, function()
        vim.fn.winrestview({ topline = top, lnum = top })
      end)
    end
    local elapsed, provider = redraw()
    if index > 10 then
      providers[#providers + 1] = provider
    end
    return elapsed
  end)
  if mode == "edit" and (10 + iterations) % 2 == 1 then
    revert()
  end
  return { redraw = redraws, provider = providers }
end

---Times one edit with its change tracking and the forced window redraw after it, then reverts both the same way.
---@param kind                          "char"|"pair"|"open"
---@param row                           integer
---@param col                           integer
---@return { edit: number, redraw: number }
function M.edit_redraw(kind, row, col)
  local apply, revert = edit_pair(kind, row, col)
  local started = hrtime()
  apply()
  local edit = (hrtime() - started) / 1e6
  local elapsed = redraw()
  revert()
  redraw()
  return { edit = edit, redraw = elapsed }
end

---Times an Ex command and the forced window redraw after it, then undoes the command.
---@param command                       string
---@return { command: number, redraw: number }
function M.command(command)
  local started = hrtime()
  vim.cmd(command)
  local ran = (hrtime() - started) / 1e6
  local elapsed = redraw()
  vim.cmd("silent undo")
  redraw()
  return { command = ran, redraw = elapsed }
end

---Loads `paths` as Lua buffers with the variant attached to each.
---@param paths                         string[]
---@return { load: number, rss: integer } Milliseconds, and the growth of the resident set in bytes.
function M.load(paths)
  collectgarbage("collect")
  local rss = vim.uv.resident_set_memory()
  local started = hrtime()
  for _, path in ipairs(paths) do
    local bufnr = vim.fn.bufadd(path)
    vim.fn.bufload(bufnr)
    vim.api.nvim_set_option_value("filetype", "lua", { buf = bufnr })
    if M.variant.attach then
      M.variant.attach(bufnr)
    end
  end
  local elapsed = (hrtime() - started) / 1e6
  collectgarbage("collect")
  return { load = elapsed, rss = vim.uv.resident_set_memory() - rss }
end

---Times the variant's cursor-moved work with the cursor at `row`, `col`.
---@param row                           integer
---@param col                           integer
---@param iterations                    integer
---@return number[]|nil
function M.matchparen(row, col, iterations)
  if not M.variant.matchparen then
    return nil
  end
  local callback = M.variant.matchparen()
  vim.api.nvim_win_set_cursor(M.winnr, { row + 1, col })
  return collect(10, iterations, function()
    local started = hrtime()
    callback()
    return (hrtime() - started) / 1e6
  end)
end

---Places the cursor and starts appending at the end of line `row` (0-based) for the parent's typed keys.
---@param row                           integer
---@return nil
function M.insert_at(row)
  vim.api.nvim_win_set_cursor(M.winnr, { row + 1, 0 })
  vim.cmd("normal! zz")
  vim.cmd("startinsert!")
end

return M
