---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.cmp.path_documentation" ---@type string

local M = {}
local BYTE_LIMIT = 1024
local REQUEST_TIMEOUT = 200
local languages = {
  js = "javascript",
  jsx = "jsx",
  md = "markdown",
  py = "python",
  rs = "rust",
  sh = "bash",
  ts = "typescript",
  tsx = "tsx",
} ---@type table<string, string>
local blocked_components = {
  [".aws"] = true,
  [".azure"] = true,
  [".docker"] = true,
  [".git"] = true,
  [".git-credentials"] = true,
  [".gnupg"] = true,
  [".kube"] = true,
  [".netrc"] = true,
  [".npmrc"] = true,
  [".pypirc"] = true,
  [".ssh"] = true,
} ---@type table<string, boolean>

---@param filepath                      string
---@return string[]|nil
local function checked_components(filepath)
  if filepath:sub(1, 1) ~= "/" or filepath:find("\0", 1, true) ~= nil then
    return nil
  end
  local components = {} ---@type string[]
  local previous = ""
  for component in filepath:gmatch("[^/\\]+") do
    local name = component:lower()
    if
      name == "."
      or name == ".."
      or blocked_components[name]
      or name:match("^%.env")
      or name:find("credential", 1, true)
      or name:find("secret", 1, true)
      or name:find("service[_%-]account")
      or name:match("^id_[a-z%d]+$")
      or name:match("%.pem$")
      or name:match("%.key$")
      or name:match("%.p12$")
      or name:match("%.pfx$")
      or name:match("%.http_request$")
      or name:match("%.http_response$")
      or name:match("%.http%.out$")
      or previous == "local" and name:match("^env%.")
    then
      return nil
    end
    components[#components + 1] = component
    previous = name
  end
  return #components > 0 and components or nil
end

---@param content                       string
---@param filepath                      string
---@return string
local function format_content(content, filepath)
  if content:find("\0", 1, true) ~= nil then
    return "Binary file"
  end
  local last = #content
  while last > 0 and content:byte(last) >= 128 and content:byte(last) < 192 do
    last = last - 1
  end
  local byte = content:byte(last) or 0
  local width = byte >= 240 and 4 or byte >= 224 and 3 or byte >= 192 and 2 or 1
  if last + width - 1 > #content then
    content = content:sub(1, math.max(0, last - 1))
  end
  local fence_length = 3
  for run in content:gmatch("`+") do
    fence_length = math.max(fence_length, #run + 1)
  end
  local fence = string.rep("`", fence_length)
  local extension = (filepath:match("%.([%w_+-]+)$") or ""):lower()
  local filetype = languages[extension] or extension
  return fence .. filetype .. "\n" .. content .. (content:sub(-1) == "\n" and "" or "\n") .. fence
end

---@param filepath                      string
---@param callback                      fun(documentation: string|nil): nil
---@return fun(): nil
function M.request(filepath, callback)
  local components = checked_components(filepath)
  if components == nil then
    callback(nil)
    return function() end
  end
  local active = true
  local timer = nil ---@type uv.uv_timer_t|nil
  local descriptor = nil ---@type integer|nil
  local busy = false
  ---@return nil
  local function close()
    if not busy and descriptor ~= nil then
      local owned = descriptor
      descriptor = nil
      vim.uv.fs_close(owned, function() end)
    end
  end
  ---@return nil
  local function cancel()
    active = false
    if timer ~= nil and not timer:is_closing() then
      timer:stop()
      timer:close()
    end
    close()
  end
  ---@param content                     ?string
  ---@return nil
  local function finish(content)
    close()
    if not active then
      return
    end
    vim.schedule(function()
      if not active then
        return
      end
      cancel()
      callback(content ~= nil and format_content(content, filepath) or nil)
    end)
  end
  timer = vim.defer_fn(function()
    if active then
      cancel()
      callback(nil)
    end
  end, REQUEST_TIMEOUT)

  ---@param expected                    uv.fs_stat.result
  ---@return nil
  local function read(expected)
    vim.uv.fs_open(filepath, bit.bor(vim.uv.constants.O_RDONLY, vim.uv.constants.O_NONBLOCK), 0, function(err, opened)
      descriptor = opened
      if not active or err ~= nil or opened == nil then
        finish(nil)
        return
      end
      busy = true
      vim.uv.fs_fstat(opened, function(stat_error, stat)
        busy = false
        if
          not active
          or stat_error ~= nil
          or stat == nil
          or stat.type ~= "file"
          or stat.dev ~= expected.dev
          or stat.ino ~= expected.ino
          or stat.nlink ~= 1
        then
          finish(nil)
          return
        end
        busy = true
        vim.uv.fs_read(opened, BYTE_LIMIT, 0, function(read_error, content)
          busy = false
          finish(read_error == nil and content or nil)
        end)
      end)
    end)
  end
  ---@param index                       integer
  ---@param parent                      string
  ---@return nil
  local function inspect(index, parent)
    local path = parent .. "/" .. components[index]
    vim.uv.fs_lstat(path, function(err, stat)
      if not active or err ~= nil or stat == nil then
        finish(nil)
      elseif index < #components then
        if stat.type == "directory" then
          inspect(index + 1, path)
        else
          finish(nil)
        end
      elseif stat.type == "file" and stat.nlink == 1 then
        read(stat)
      else
        finish(nil)
      end
    end)
  end
  inspect(1, "")
  return cancel
end

return M
