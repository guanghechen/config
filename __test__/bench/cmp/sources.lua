---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.cmp.sources" ---@type string

local Data = require("__test__.bench.cmp.data")
local M = {}

---@param functions                     table<string, fun(callback: fun(response: table): nil): any>
---@param samples                       integer
---@param prepare                       ?fun(name: string, sample: integer): nil
---@return table
local function measure(functions, samples, prepare)
  local values, returns, counts, first = {}, {}, {}, {}
  local names = vim.tbl_keys(functions)
  table.sort(names)
  for _, name in ipairs(names) do
    values[name], returns[name] = {}, {}
  end
  for sample = 1, samples + 5 do
    for step = 1, #names do
      local name = names[(sample + step - 2) % #names + 1]
      if prepare ~= nil then
        prepare(name, sample)
      end
      collectgarbage("collect")
      local done, elapsed = false, nil
      local start = vim.uv.hrtime()
      functions[name](function(response)
        elapsed = (vim.uv.hrtime() - start) / 1e6
        counts[name] = #assert(response.items)
        done = true
      end)
      local immediate = (vim.uv.hrtime() - start) / 1e6
      assert(
        vim.wait(5000, function()
          return done
        end, 1),
        name .. " source timeout"
      )
      if sample == 1 then
        first[name] = elapsed
      end
      if sample > 5 then
        values[name][#values[name] + 1] = elapsed
        returns[name][#returns[name] + 1] = immediate
      end
    end
  end
  local result = {}
  for _, name in ipairs(names) do
    result[name] = {
      latency_ms = Data.stats(values[name]),
      synchronous_ms = Data.stats(returns[name]),
      count = counts[name],
      first_ms = first[name],
    }
  end
  return result
end

---@param context                       table
---@return table
local function blink_context(context)
  return {
    id = 1,
    bufnr = context.bufnr,
    line = context.line,
    cursor = { context.row + 1, context.col },
    bounds = { start_col = context.start_col + 1, length = #context.keyword },
    get_keyword = function()
      return context.keyword
    end,
    get_line = function()
      return context.line
    end,
  }
end

---@param options                       table
---@return table
function M.run(options)
  local Runtime = require("__test__.fixtures.era.keystroke.cmp.runtime")
  Runtime.setup(options.baseline)
  require("blink.cmp.fuzzy").set_implementation("rust")
  local result = { buffers = {}, paths = {}, snippets = {} }
  for _, count in ipairs({ 500, 4000 }) do
    local labels = Data.labels(count)
    local bufnr = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_set_current_buf(bufnr)
    local lines = { "" }
    for index = 1, #labels, 5 do
      lines[#lines + 1] = table.concat(vim.list_slice(labels, index, index + 4), " ")
    end
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    dot.tab.resolve = function()
      return { bufs = { { bufnr = bufnr } } }
    end
    local context = Runtime.context("")
    local own = require("era.keystroke.cmp.source.buffer")
    local theirs = require("blink.cmp.sources.buffer").new({
      get_bufnrs = function()
        return { bufnr }
      end,
    })
    local functions = {
      era = function(callback)
        own.complete(context, callback)
      end,
      blink = function(callback)
        theirs:get_completions(blink_context(context), callback)
      end,
    }
    result.buffers[#result.buffers + 1] = {
      words = count,
      bytes = vim.api.nvim_buf_get_offset(bufnr, #lines),
      hot = measure(functions, options.samples),
      changedtick = measure(functions, options.samples, function(_, sample)
        local line = sample % 2 == 0 and lines[2] or lines[2]:gsub("_00001", "_90001")
        vim.api.nvim_buf_set_lines(bufnr, 1, 2, false, { line })
      end),
    }
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end

  local temp = assert(vim.uv.fs_mkdtemp(vim.fn.tempname() .. "-cmp-path-XXXXXX"))
  local ok, err = xpcall(function()
    for _, count in ipairs({ 200, 2000 }) do
      for index = 1, count do
        local fd = assert(vim.uv.fs_open(temp .. "/candidate_" .. string.format("%05d", index) .. ".lua", "w", 384))
        assert(vim.uv.fs_close(fd))
      end
      local context = Runtime.context('"' .. temp .. "/can")
      local own = require("era.keystroke.cmp.source.path")
      local theirs = require("blink.cmp.sources.path").new({ show_hidden_files_by_default = true })
      result.paths[#result.paths + 1] = {
        entries = count,
        timings = measure({
          era = function(callback)
            return own.complete(context, callback)
          end,
          blink = function(callback)
            return theirs:get_completions(blink_context(context), callback)
          end,
        }, options.samples),
      }
    end
  end, debug.traceback)
  vim.fn.delete(temp, "rf")
  assert(ok, err)

  local friendly = vim.fn.stdpath("data") .. "/lazy/friendly-snippets"
  assert(vim.uv.fs_stat(friendly .. "/package.json"), "friendly-snippets must already exist")
  vim.opt.runtimepath:append(friendly)
  vim.api.nvim_set_option_value("filetype", "lua", { buf = 0 })
  local context = Runtime.context("")
  local own = require("era.keystroke.cmp.source.snippets")
  local theirs = require("blink.cmp.sources.snippets.default").new({ friendly_snippets = true, search_paths = {} })
  result.snippets = measure({
    era = function(callback)
      own.complete(context, callback)
    end,
    blink = function(callback)
      theirs:get_completions(blink_context(context), callback)
    end,
  }, options.samples)
  return result
end

return M
