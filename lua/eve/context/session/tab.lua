---@class eve.context.tab.buf.data
---@field public filepath               string
---@field public pinned                 boolean

---@class eve.context.tab.meta.data
---@field public tabtype                eve.builtin.tab.TypeEnum
---@field public bufs                   eve.context.tab.buf.data[]

---@class eve.context.tab.data
---@field public list                   eve.context.tab.meta.data[]

---@class eve.context.tab.state

---@class eve.context.tab : eve.context.tab.state
---@field public defaults               fun(): eve.context.tab.data
---@field public dump                   fun(): eve.context.tab.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): eve.context.tab.data
local M = {}

---@return eve.context.tab.data
function M.defaults()
  ---@type eve.context.tab.data
  return {
    list = {},
  }
end

---@param data                        any
---@return eve.context.tab.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.context.tab.data
  if type(data) == "table" then
    if type(data.list) == "table" then
      for _, item in ipairs(data.list) do
        if type(item) == "table" and type(item.tabtype) == "string" and type(item.bufs) == "table" then
          ---@type eve.context.tab.meta.data
          local meta = {
            tabtype = item.tabtype,
            bufs = {},
          }
          local bufs = meta.bufs ---@type eve.context.tab.buf.data[]

          for _, buf in ipairs(item.bufs) do
            if type(buf) == "table" and type(buf.filepath) == "string" and type(buf.pinned) == "boolean" then
              local meta_buf = { filepath = buf.filepath, pinned = buf.pinned } ---@type eve.context.tab.buf.data
              bufs[#bufs + 1] = meta_buf
            end
          end
          table.insert(resolved.list, meta)
        end
      end
    end
  end

  ---@type eve.context.tab.data
  return resolved
end

---@return eve.context.tab.data
function M.dump()
  local list = {} ---@type eve.context.tab.meta.data[]
  local tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]
  for _, tabnr in ipairs(tabnrs) do
    local meta = eve.tab.resolve(tabnr, false) ---@type eve.builtin.tab.IMeta|nil
    if meta ~= nil then
      local tabtype = meta.tabtype ---@type  eve.builtin.tab.TypeEnum
      local bufs = {} ---@type eve.context.tab.buf.data[]
      local meta_data = { tabtype = tabtype, bufs = bufs } ---@type eve.context.tab.meta.data
      for _, buf in ipairs(meta.bufs) do
        local bufnr = buf.bufnr ---@type integer
        local pinned = buf.pinned ---@type boolean
        if bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr) then
          local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
          local buf_data = { filepath = filepath, pinned = pinned } ---@type eve.context.tab.buf.data
          bufs[#bufs + 1] = buf_data
        end
      end
      list[#list + 1] = meta_data
    end
  end

  ---@type eve.context.tab.data
  return {
    list = list,
  }
end

---@param raw_data                      any
---@return nil
function M.load(raw_data)
  M.__meta_map__ = {}

  local data = M.normalize(raw_data) ---@type eve.context.tab.data

  local tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]
  for tabid, tab_data in ipairs(data.list) do
    local tabnr = tabnrs[tabid] ---@type integer|nil
    if tabnr == nil then
      goto continue
    end

    local meta = eve.tab.resolve(tabnr, true) ---@type eve.builtin.tab.IMeta|nil
    if meta == nil then
      goto continue
    end

    for _, buf in ipairs(meta.bufs) do
      if vim.api.nvim_buf_is_valid(buf.bufnr) then
        local filepath = vim.api.nvim_buf_get_name(buf.bufnr) ---@type string
        for _, buf_data in ipairs(tab_data.bufs) do
          if buf_data.filepath == filepath then
            buf.pinned = buf_data.pinned == true
            break
          end
        end
      end
    end

    eve.tab.set_type(tabnr, tab_data.tabtype)
    eve.tab.refresh_bufs(meta.bufs)
    eve.tab.rearrange_bufs(meta.bufs)
    ::continue::
  end
end

return M
