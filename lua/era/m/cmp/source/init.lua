---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.cmp.source" ---@type string

local util = require("era.m.cmp.source.util")

local providers = {
  buffer = require("era.m.cmp.source.buffer"),
  dict = require("era.m.cmp.source.dict"),
  path = require("era.m.cmp.source.path"),
  slash = require("era.m.cmp.source.slash"),
  snippets = require("era.m.cmp.source.snippets"),
}

local code_filetypes = {} ---@type table<string, boolean>
for _, filetype in ipairs(stl.filetype.list_code_filetypes()) do
  code_filetypes[filetype] = true
end

local M = {}
local failed_sources = {} ---@type table<string, boolean>
local async_sources = { path = true, path_at = true } ---@type table<string, boolean>

---@param filetype                      string
---@return string[]
local function resolve_sources(filetype)
  if filetype == stl.filetype.UX_PICKER_FINDER then
    return { "path" }
  end
  if filetype == stl.filetype.UX_SEARCHER_FINDER then
    return { "path", "dict" }
  end
  if filetype == stl.filetype.NOTEPAD or filetype == "markdown" then
    return { "slash", "path_at", "path", "snippets", "buffer", "dict" }
  end
  if code_filetypes[filetype] then
    return { "path_at", "path", "snippets", "buffer", "dict" }
  end
  return {}
end

---@param source                        string
---@param err                           any
local function report(source, err)
  if err == nil or failed_sources[source] then
    return
  end
  failed_sources[source] = true
  stl.reporter.error({
    from = __module_name__,
    subject = source,
    message = "Completion provider failed.",
    details = err,
  })
end

---@param params                        lsp.CompletionParams
---@param history                       yoz.cmp.IUsage|table<string, integer|{ count: integer, last_used: integer }|yoz.cmp.IUsageRecord>
---@param callback                      fun(result: lsp.CompletionList): nil
---@param bufnr?                        integer
---@return fun()
---@return fun(): lsp.CompletionList
function M.complete(params, history, callback, bufnr)
  local context = util.context(params, bufnr)
  if context == nil then
    local result = { isIncomplete = false, items = {} } ---@type lsp.CompletionList
    callback(result)
    return function() end, function()
      return result
    end
  end

  local sources = resolve_sources(context.filetype)
  local results = {} ---@type table<string, lsp.CompletionItem[]>
  local cancels = {} ---@type fun()[]
  local pending = 0 ---@type integer
  local collecting = true ---@type boolean
  local cancelled = false ---@type boolean
  local settled = false ---@type boolean

  local function snapshot()
    local items = {} ---@type lsp.CompletionItem[]
    for _, source in ipairs(sources) do
      vim.list_extend(items, results[source] or {})
    end
    return { isIncomplete = true, items = items }
  end

  local function finish()
    if cancelled or settled or collecting or pending ~= 0 then
      return
    end
    settled = true
    local ok, result = xpcall(snapshot, debug.traceback)
    if ok then
      callback(result)
    else
      stl.reporter.error({
        from = __module_name__,
        subject = "aggregate",
        message = "Failed to aggregate completion sources.",
        details = result,
      })
      callback({ isIncomplete = false, items = {} })
    end
  end

  for _, source_name in ipairs(sources) do
    local source = source_name ---@type string
    local provider = providers[source == "path_at" and "path" or source] ---@type table
    local method = source == "path_at" and provider.complete_at or provider.complete
    if async_sources[source] then
      pending = pending + 1
      local ok, cancel = xpcall(function()
        return method(context, function(items, err)
          if cancelled or settled then
            return
          end
          pending = pending - 1
          results[source] = items
          if err == nil then
            failed_sources[source] = nil
          else
            report(source, err)
          end
          finish()
        end)
      end, debug.traceback)
      if ok and type(cancel) == "function" then
        cancels[#cancels + 1] = cancel
      elseif not ok then
        pending = pending - 1
        results[source] = {}
        report(source, cancel)
      end
    else
      local ok, result = xpcall(function()
        return method(context, history)
      end, debug.traceback)
      if ok then
        failed_sources[source] = nil
        results[source] = result
      else
        results[source] = {}
        report(source, result)
      end
    end
  end

  collecting = false
  finish()
  local function cancel_all()
    if cancelled or settled then
      return
    end
    cancelled = true
    for _, cancel in ipairs(cancels) do
      cancel()
    end
  end
  return cancel_all, snapshot
end

---@param bufnr                         integer
---@return boolean
function M.is_enabled(bufnr)
  if not util.is_safe_buffer(bufnr) then
    return false
  end
  if vim.b[bufnr][dot.var.N_CMP_DOCUMENTATION] == true then
    return false
  end
  if vim.api.nvim_get_option_value("buftype", { buf = bufnr }) == "nowrite" then
    return false
  end
  return stl.filetype.is_cmp_enabled(vim.api.nvim_get_option_value("filetype", { buf = bufnr }))
end

---@param bufnr                         integer
function M.clear_buffer(bufnr)
  providers.buffer.clear(bufnr)
end

return M
