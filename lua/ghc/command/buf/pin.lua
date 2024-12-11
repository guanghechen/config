local status = require("eve.builtin.status")
local state = require("eve.state")
local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids

eve.commander.register({
  uuid = uuids.buf_pin,
  desc = "buf: pin",
  action = function()
    local bufnr = vim.api.nvim_get_current_buf() ---@type integer
    local meta_buf = eve.buf.resolve(bufnr) ---@type eve.t.state.state.buf.IMeta|nil
    if meta_buf ~= nil then
      local pinned = meta_buf.pinned ---@type boolean
      local filepath = meta_buf.filepath ---@type string

      local pinned_list = state.state.bookmark.pinned:snapshot() ---@type string[]
      local k = eve.util.find_index(pinned_list, filepath) ---@type integer|nil
      if k == nil then
        table.insert(pinned_list, filepath)
      else
        for i = k + 1, #pinned_list, 1 do
          pinned_list[k] = pinned_list[i]
          k = k + 1
        end
        pinned_list[k] = nil
      end

      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local meta_tab = eve.tab.resolve(tabnr) ---@type eve.t.state.state.tab.IMeta|nil
      local bufnrs = meta_tab and meta_tab.bufnrs or nil ---@type integer[]|nil
      if bufnrs ~= nil then
        local i = eve.util.find_index(bufnrs, bufnr) ---@type integer|nil
        if i ~= nil then
          if pinned then
            local j = i + 1 ---@type integer
            while j <= #bufnrs do
              local mb = eve.buf.resolve(bufnrs[j]) ---@type eve.t.state.state.buf.IMeta|nil
              if mb == nil or not mb.pinned then
                break
              else
                bufnrs[j - 1] = bufnrs[j]
              end
              j = j + 1
            end
            bufnrs[j - 1] = bufnr
          else
            local j = 1 ---@type integer
            while j <= #bufnrs do
              local mb = eve.buf.resolve(bufnrs[j]) ---@type eve.t.state.state.buf.IMeta|nil
              if mb == nil or not mb.pinned then
                break
              end
              j = j + 1
            end
            if j <= i then
              for x = i, j + 1, -1 do
                bufnrs[x] = bufnrs[x - 1]
              end
              bufnrs[j] = bufnr
            end
          end
        end
      end

      meta_buf.pinned = not pinned
      status.tabline_dirtier:mark_dirty()
    end
  end,
})
