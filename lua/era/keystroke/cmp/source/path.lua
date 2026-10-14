---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.keystroke.cmp.source.path" ---@type string

local Context = require("era.keystroke.cmp.context")
local Item = require("era.keystroke.cmp.item")
local M = {}

---@class era.keystroke.cmp.source.path.ITarget
---@field public dirname                string
---@field public start_col              integer
---@field public source                 string

---@param context                       era.keystroke.cmp.IContext
---@return era.keystroke.cmp.source.path.ITarget|nil
function M.target(context)
  local before = context.line:sub(1, context.col)
  local quoted_start, token = before:match("()[\"'`]([^\"'`]*)$")
  local start = quoted_start and quoted_start + 1 or nil
  if start == nil then
    start, token = before:match("()([^%s\"'`<>=,;|%(%)[%]{}]*)$")
  end
  if start == nil or token == nil then
    return nil
  end
  local at_path = token:sub(1, 1) == "@"
  local finder = context.filetype == stl.filetype.UX_PICKER_FINDER
    or context.filetype == stl.filetype.UX_SEARCHER_FINDER
  if not at_path and not finder and not token:find("[/\\]") then
    return nil
  end
  if not yoz.string.is_utf8(token) then
    return nil
  end
  local prefix = token:match("^(.*[/\\])") or (at_path and "@" or "")
  local dirname = at_path and prefix:sub(2) or prefix
  local root = dot.path.cwd()
  if not at_path and not finder then
    local filename = vim.api.nvim_buf_get_name(context.bufnr)
    if filename ~= "" then
      if not yoz.string.is_utf8(filename) then
        return nil
      end
      root = dot.path.dirname(filename)
    end
  end
  if not yoz.string.is_utf8(root) then
    return nil
  end
  if dirname:sub(1, 2) == "~/" or dirname:sub(1, 2) == "~\\" then
    local home_dir = vim.fn.expand("~")
    if not yoz.string.is_utf8(home_dir) then
      return nil
    end
    dirname = dot.path.join(home_dir, dirname:sub(3))
  elseif dirname:sub(1, 1) == "$" then
    local name, rest = dirname:match("^%${?([%w_]+)}?[/\\](.*)$")
    local value = name and vim.env[name] or nil
    if type(value) ~= "string" or not yoz.string.is_utf8(value) then
      return nil
    end
    dirname = dot.path.join(value, rest)
  end
  return {
    dirname = dot.path.resolve(root, dirname),
    start_col = start - 1 + #prefix,
    source = at_path and "path_at" or "path",
  }
end

---@param context                       era.keystroke.cmp.IContext
---@param callback                      fun(response: era.keystroke.cmp.IResponse): nil
---@return (fun(): nil)|nil
function M.complete(context, callback)
  local target = M.target(context)
  if target == nil then
    callback({ items = {}, incomplete = true })
    return nil
  end
  local cancelled = false
  local settled = false
  local scanned = false
  local pending = 0
  local items = {} ---@type era.keystroke.cmp.IItem[]
  local timer = assert(vim.uv.new_timer())
  local requests = {}

  ---@return nil
  local function close_timer()
    if not timer:is_closing() then
      timer:stop()
      timer:close()
    end
  end

  ---@param incomplete                  boolean
  ---@return nil
  local function finish(incomplete)
    if cancelled or settled then
      return
    end
    settled = true
    close_timer()
    for request in pairs(requests) do
      pcall(vim.uv.cancel, request)
    end
    requests = {}
    callback({ items = items, incomplete = incomplete })
  end

  ---@param name                        string
  ---@param kind                        string
  ---@return nil
  local function append(name, kind)
    if cancelled or settled then
      return
    end
    local directory = kind == "directory"
    local text = name .. (directory and "/" or "")
    local end_col = context.col
    if directory and context.line:sub(context.col + 1, context.col + 1) == "/" then
      end_col = end_col + 1
    end
    items[#items + 1] = Item.new(context, target.source, {
      label = text,
      kind = directory and vim.lsp.protocol.CompletionItemKind.Folder or vim.lsp.protocol.CompletionItemKind.File,
      filterText = name,
      textEdit = Item.text_edit(context, target.start_col, text, end_col),
      data = { full_path = dot.path.join(target.dirname, name) },
    })
  end

  timer:start(
    2000,
    0,
    vim.schedule_wrap(function()
      finish(true)
    end)
  )
  local scan_request
  scan_request = vim.uv.fs_scandir(
    target.dirname,
    vim.schedule_wrap(function(err, scan)
      if scan_request ~= nil then
        requests[scan_request] = nil
      end
      if cancelled or settled then
        return
      end
      if err ~= nil or scan == nil then
        finish(true)
        return
      end

      ---@return nil
      local function consume()
        if cancelled or settled then
          return
        end
        for _ = 1, 200 do
          local name, kind = vim.uv.fs_scandir_next(scan)
          if name == nil then
            scanned = true
            if pending == 0 then
              finish(false)
            end
            return
          end
          if yoz.string.is_utf8(name) then
            if kind == "link" or kind == nil or kind == "unknown" then
              pending = pending + 1
              local request
              request = vim.uv.fs_stat(
                dot.path.join(target.dirname, name),
                vim.schedule_wrap(function(_, stat)
                  if request ~= nil then
                    requests[request] = nil
                  end
                  pending = pending - 1
                  if stat ~= nil then
                    append(name, stat.type)
                  end
                  if scanned and pending == 0 then
                    finish(false)
                  end
                end)
              )
              if request ~= nil then
                requests[request] = true
              end
            else
              append(name, kind)
            end
          end
        end
        vim.schedule(consume)
      end
      consume()
    end)
  )
  if scan_request ~= nil then
    requests[scan_request] = true
  end

  return function()
    cancelled = true
    close_timer()
    for request in pairs(requests) do
      pcall(vim.uv.cancel, request)
    end
    requests = {}
  end
end

---@param item                          era.keystroke.cmp.IItem
---@param callback                      fun(raw: lsp.CompletionItem): nil
---@return (fun(): nil)|nil
function M.resolve(item, callback)
  local full_path = item.raw.data.full_path ---@type string
  if Context.is_private(full_path) then
    callback(item.raw)
    return nil
  end
  local cancelled = false
  -- A path can change since the directory scan. Opening a FIFO for reading may never complete.
  vim.uv.fs_stat(
    full_path,
    vim.schedule_wrap(function(_, stat)
      if cancelled then
        return
      end
      if stat == nil or stat.type ~= "file" then
        callback(item.raw)
        return
      end
      vim.uv.fs_open(full_path, "r", 438, function(err, fd)
        if err ~= nil or fd == nil then
          vim.schedule(function()
            if not cancelled then
              callback(item.raw)
            end
          end)
          return
        end
        if cancelled then
          vim.uv.fs_close(fd, function() end)
          return
        end
        vim.uv.fs_read(fd, 65536, 0, function(read_error, content)
          vim.uv.fs_close(fd, function() end)
          vim.schedule(function()
            if cancelled then
              return
            end
            local raw = vim.tbl_extend("force", {}, item.raw)
            if read_error == nil and type(content) == "string" then
              if content:find("\0", 1, true) then
                raw.documentation = { kind = "plaintext", value = "Binary file" }
              else
                local extension = full_path:match("%.([%w_]+)$") or ""
                raw.documentation = { kind = "markdown", value = "```" .. extension .. "\n" .. content .. "\n```" }
              end
            end
            callback(raw)
          end)
        end)
      end)
    end)
  )
  return function()
    cancelled = true
  end
end

return M
