---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.nvim.buf" ---@type string

---@class era.nvim.buf
local M = {}

----------------------------------------------------------------------------------------------------
-- close
----------------------------------------------------------------------------------------------------

---@param tabnr                         integer
---@param bufnrs                        integer[]
---@return nil
local function __close__(tabnr, bufnrs)
  if #bufnrs < 1 then
    return
  end

  dot.tab.on_bufs_close(tabnr, bufnrs)

  local bufnrs_unreferenced = dot.tab.retrieve_unreferenced_bufnrs() ---@type integer[]
  for _, bufnr in ipairs(bufnrs_unreferenced) do
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

---@return nil
function M.close()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr = dot.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
  if winnr == nil then
    local bufnr = vim.api.nvim_get_current_buf() ---@type integer
    stl.nvim.buf.close(bufnr)
    return
  end

  local meta = dot.win.resolve(winnr, false) ---@type dot.win.IMeta|nil
  if meta == nil then
    local bufnr = vim.api.nvim_get_current_buf() ---@type integer
    stl.nvim.buf.close(bufnr)
    return
  end

  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local history = meta.history ---@type stl.c.History|nil
  if history == nil then
    stl.nvim.buf.close(bufnr)
    return
  end

  local bufnr_target = nil ---@type integer|nil

  local item_present, _ = history:present() ---@type dot.win.IFilepathHistoryItem|nil, integer
  if
    item_present ~= nil
    and item_present.bufnr ~= nil
    and item_present.bufnr ~= bufnr
    and vim.api.nvim_buf_is_valid(item_present.bufnr)
  then
    bufnr_target = item_present.bufnr ---@type integer
  else
    while true do
      local item, is_bot = history:backward()
      ---@cast item dot.win.IFilepathHistoryItem|nil
      ---@cast is_bot boolean

      if item == nil then
        break
      end

      if item.bufnr ~= nil and vim.api.nvim_buf_is_valid(item.bufnr) then
        bufnr_target = item.bufnr ---@type integer
        item.filepath = vim.api.nvim_buf_get_name(bufnr_target) ---@type string
        break
      end

      bufnr_target = dot.buf.loadfile(item.filepath) ---@type integer|nil
      if bufnr_target ~= nil then
        item.bufnr = bufnr_target ---@type integer
        break
      end

      if is_bot then
        break
      end
    end
  end

  if bufnr_target ~= nil then
    vim.api.nvim_win_set_buf(winnr, bufnr_target)
  end

  __close__(tabnr, { bufnr })
end

---@return nil
function M.close_others()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local meta = dot.tab.resolve(tabnr, false) ---@type dot.tab.IMeta|nil
  if meta == nil then
    stl.reporter.error({
      from = __module_name__,
      subject = "close_others",
      message = "Cannot resolve the meta for the current tab.",
      details = { tabnr = tabnr },
    })
    return
  end

  local bufnrs_to_remove = {} ---@type integer[]
  local bufnrs_visible = stl.nvim.tab.list_visible_bufnrs(tabnr) ---@type table<integer, boolean>

  for _, buf in ipairs(meta.bufs) do
    if not buf.pinned and not bufnrs_visible[buf.bufnr] then
      table.insert(bufnrs_to_remove, buf.bufnr)
    end
  end

  __close__(tabnr, bufnrs_to_remove)
end

---@return nil
function M.close_to_leftest()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local meta = dot.tab.resolve(tabnr, false) ---@type dot.tab.IMeta|nil
  if meta == nil then
    stl.reporter.error({
      from = __module_name__,
      subject = "close_to_leftest",
      message = "Cannot resolve the meta for the current tab.",
      details = { tabnr = tabnr },
    })
    return
  end

  local _, bufid_sourcefile = dot.tab.retrieve_buf_sourcefile(tabnr) ---@type dot.tab.IBufItem|nil, integer|nil
  if bufid_sourcefile == nil then
    return
  end

  local bufs = meta.bufs ---@type dot.tab.IBufItem[]
  local bufnrs_visible = stl.nvim.tab.list_visible_bufnrs(tabnr) ---@type table<integer, boolean>
  local bufnrs_to_remove = {} ---@type integer[]

  for i = bufid_sourcefile - 1, 1, -1 do
    local buf = bufs[i] ---@type dot.tab.IBufItem
    if not buf.pinned and not bufnrs_visible[buf.bufnr] then
      table.insert(bufnrs_to_remove, buf.bufnr)
    end
  end

  __close__(tabnr, bufnrs_to_remove)
end

---@return nil
function M.close_to_rightest()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local meta = dot.tab.resolve(tabnr, false) ---@type dot.tab.IMeta|nil
  if meta == nil then
    stl.reporter.error({
      from = __module_name__,
      subject = "close_to_rightest",
      message = "Cannot resolve the meta for the current tab.",
      details = { tabnr = tabnr },
    })
    return
  end

  local _, bufid_sourcefile = dot.tab.retrieve_buf_sourcefile(tabnr) ---@type dot.tab.IBufItem|nil, integer|nil
  if bufid_sourcefile == nil then
    return
  end

  local bufs = meta.bufs ---@type dot.tab.IBufItem[]
  local bufnrs_visible = stl.nvim.tab.list_visible_bufnrs(tabnr) ---@type table<integer, boolean>
  local bufnrs_to_remove = {} ---@type integer[]

  for i = bufid_sourcefile + 1, #bufs, 1 do
    local buf = bufs[i] ---@type dot.tab.IBufItem
    if not buf.pinned and not bufnrs_visible[buf.bufnr] then
      table.insert(bufnrs_to_remove, buf.bufnr)
    end
  end

  __close__(tabnr, bufnrs_to_remove)
end

----------------------------------------------------------------------------------------------------
-- focus
----------------------------------------------------------------------------------------------------

---@param bufid                         integer the index of buffer list
---@return nil
function M.focus(bufid)
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local meta = dot.tab.resolve(tabnr, false) ---@type dot.tab.IMeta|nil
  if meta == nil then
    stl.reporter.error({
      from = __module_name__,
      subject = "focus",
      message = "Cannot resolve the meta for the current tab.",
      details = { tabnr = tabnr, bufid = bufid },
    })
    return
  end

  local bufs = meta.bufs ---@type dot.tab.IBufItem[]
  local bufid_next = stl.fn.navigate_limit(0, bufid, #bufs) ---@type integer
  M.open(bufs[bufid_next].bufnr)
end

---@param step                          ?integer
---@return nil
function M.focus_left(step)
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local meta = dot.tab.resolve(tabnr, false) ---@type dot.tab.IMeta|nil
  if meta == nil then
    stl.reporter.error({
      from = __module_name__,
      subject = "focus_left",
      message = "Cannot resolve the meta for the current tab.",
      details = { tabnr = tabnr },
    })
    return
  end

  local _, bufid_sourcefile = dot.tab.retrieve_buf_sourcefile(tabnr) ---@type dot.tab.IBufItem|nil, integer|nil
  if bufid_sourcefile == nil then
    return
  end

  step = math.max(1, step or vim.v.count1 or 1)

  local bufs = meta.bufs ---@type dot.tab.IBufItem[]
  local bufid_next = stl.fn.navigate_circular(bufid_sourcefile, -step, #bufs) ---@type integer
  M.open(bufs[bufid_next].bufnr)
end

---@param step                          ?integer
---@return nil
function M.focus_right(step)
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local meta = dot.tab.resolve(tabnr, false) ---@type dot.tab.IMeta|nil
  if meta == nil then
    stl.reporter.error({
      from = __module_name__,
      subject = "focus_right",
      message = "Cannot resolve the meta for the current tab.",
      details = { tabnr = tabnr },
    })
    return
  end

  local _, bufid_sourcefile = dot.tab.retrieve_buf_sourcefile(tabnr) ---@type dot.tab.IBufItem|nil, integer|nil
  if bufid_sourcefile == nil then
    return
  end

  step = math.max(1, step or vim.v.count1 or 1)
  local bufs = meta.bufs ---@type dot.tab.IBufItem[]
  local bufid_next = stl.fn.navigate_circular(bufid_sourcefile, step, #bufs) ---@type integer
  M.open(bufs[bufid_next].bufnr)
end

----------------------------------------------------------------------------------------------------
-- new
----------------------------------------------------------------------------------------------------

---@return nil
function M.new()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr_sourcefile = dot.tab.retrieve_winnr_sourcefile(tabnr) or dot.win.pick_sourcefile() ---@type integer|nil
  if winnr_sourcefile == nil then
    return
  end

  local bufnr = vim.api.nvim_create_buf(true, true) ---@type integer
  vim.api.nvim_set_option_value("buflisted", true, { buf = bufnr })
  vim.api.nvim_set_option_value("buftype", "", { buf = bufnr })
  vim.api.nvim_set_option_value("filetype", "text", { buf = bufnr })
  vim.api.nvim_set_option_value("readonly", false, { buf = bufnr })
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })

  local cwd = dot.path.cwd() ---@type string
  local filepath = dot.buf.pick_filepath(cwd) ---@type string|nil
  if filepath ~= nil then
    vim.api.nvim_buf_set_name(bufnr, filepath)
  end

  vim.api.nvim_win_set_buf(winnr_sourcefile, bufnr)
end

----------------------------------------------------------------------------------------------------
-- open
----------------------------------------------------------------------------------------------------

---@param bufnr                         integer the stable unique number of the buffer
---@return nil
function M.open(bufnr)
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr_sourcefile = dot.tab.retrieve_winnr_sourcefile(tabnr) or dot.win.pick_sourcefile() ---@type integer|nil
  if winnr_sourcefile ~= nil then
    vim.api.nvim_win_set_buf(winnr_sourcefile, bufnr)
  end
end

----------------------------------------------------------------------------------------------------
-- pin
----------------------------------------------------------------------------------------------------

---@return nil
function M.toggle_pin()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local meta = dot.tab.resolve(tabnr, false) ---@type dot.tab.IMeta|nil
  if meta == nil then
    return
  end

  local _, bufid_sourcefile = dot.tab.retrieve_buf_sourcefile(tabnr) ---@type dot.tab.IBufItem|nil, integer|nil
  if bufid_sourcefile == nil then
    return
  end

  local buf = meta.bufs[bufid_sourcefile] ---@type dot.tab.IBufItem
  local filepath = vim.api.nvim_buf_get_name(buf.bufnr) ---@type string

  local pinned_list = dot.context.bookmark.pinned:snapshot() ---@type string[]
  local k = stl.table.find_index(pinned_list, filepath) ---@type integer|nil
  if k == nil then
    table.insert(pinned_list, filepath)
  else
    for i = k + 1, #pinned_list, 1 do
      pinned_list[k] = pinned_list[i]
      k = k + 1
    end
    pinned_list[k] = nil
  end

  dot.tab.add_buf(tabnr, buf.bufnr, not buf.pinned)
  dot.state.status.dirtier_tabline:mark_dirty()
end

----------------------------------------------------------------------------------------------------
-- save
----------------------------------------------------------------------------------------------------

---@param args                          ?string
---@return nil
function M.save(args)
  local noformat = args == "noformat" ---@type boolean
  local cwd = dot.path.cwd() ---@type string
  local workspace = dot.path.workspace() ---@type string

  local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
  local bufnrs_modified = {} ---@type integer[]
  local bufnrs_new_file = {} ---@type integer[]

  for _, bufnr in ipairs(bufnrs) do
    if vim.api.nvim_get_option_value("modified", { buf = bufnr }) and vim.api.nvim_get_option_value("buftype", { buf = bufnr }) == "" then
      local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
      if #filepath > 0 and yoz.path.is_absolute(filepath) then
        table.insert(bufnrs_modified, bufnr)

        if not yoz.path.is_exist(filepath) then
          table.insert(bufnrs_new_file, bufnr)
        end
      end
    end
  end

  local count_modified = #bufnrs_modified ---@type integer
  local count_new_file = #bufnrs_new_file ---@type integer
  local count_ready = 0 ---@type integer

  if count_modified < 1 then
    return
  end

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr_sourcefile = dot.tab.retrieve_winnr_sourcefile(tabnr) or dot.win.pick_sourcefile() ---@type integer|nil
  if winnr_sourcefile == nil then
    stl.reporter.error({
      from = __module_name__,
      subject = "save",
      message = "Cannot find a valid sourcefile winnr",
    })
    return
  end

  ---@return nil
  local function check()
    if count_ready == count_new_file then
      for _, bufnr in ipairs(bufnrs_modified) do
        if vim.api.nvim_buf_is_valid(bufnr) then
          vim.api.nvim_buf_call(bufnr, function()
            if noformat then
              vim.cmd("noautocmd write")
            else
              vim.cmd("write")
            end
          end)
        end
      end

      local winnrs = vim.api.nvim_list_wins() ---@type integer[]
      for _, winnr in ipairs(winnrs) do
        dot.state.status.dirty_winline_nr:next(winnr)
      end
      dot.state.status.dirtier_statusline:mark_dirty()
      dot.state.status.dirtier_tabline:mark_dirty()
    end
  end

  for _, bufnr in ipairs(bufnrs_new_file) do
    local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
    local initial_text = yoz.path.is_descendant(workspace, filepath) and dot.path.relative(cwd, filepath, "/")
      or filepath ---@type string
    vim.api.nvim_win_set_buf(winnr_sourcefile, bufnr)

    vim.ui.input({
      relative = "editor",
      prompt = "Save file as",
      default = initial_text,
    }, function(text)
      if text == nil then
        return
      end

      local next_filepath = dot.path.resolve(cwd, text) ---@type string

      ---@return nil
      local on_save = function()
        vim.api.nvim_buf_set_name(bufnr, next_filepath)

        count_ready = count_ready + 1
        check()
      end

      if yoz.path.is_exist_file(next_filepath) then
        vim.ui.select({ "Yes", "No" }, {
          name = __module_name__,
          prompt = "The file is already existed, do you want to override it?",
        }, function(choice)
          if choice == "Yes" then
            on_save()
          end
        end)
        return false
      end

      if yoz.path.is_exist_directory(next_filepath) then
        stl.reporter.error({
          from = __module_name__,
          subject = "save",
          message = "Cannot save a file into a directory.",
          details = {
            bufnr = bufnr,
            text = text,
            cwd = cwd,
            workspace = workspace,
            next_filepath = next_filepath,
          },
        })

        count_ready = count_ready + 1
        check()
        return false
      end

      vim.schedule(on_save)
      return true
    end)
  end

  check()
end

----------------------------------------------------------------------------------------------------
-- swap
----------------------------------------------------------------------------------------------------

---@param step                          ?integer
---@return nil
function M.swap_left(step)
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local meta = dot.tab.resolve(tabnr, false) ---@type dot.tab.IMeta|nil
  if meta == nil then
    stl.reporter.error({
      from = __module_name__,
      subject = "swap_left",
      message = "Cannot resolve the meta for the current tab.",
      details = { tabnr = tabnr },
    })
    return
  end

  local _, bufid_sourcefile = dot.tab.retrieve_buf_sourcefile(tabnr) ---@type dot.tab.IBufItem|nil, integer|nil
  if bufid_sourcefile == nil then
    return
  end

  step = math.max(1, step or vim.v.count1 or 1)
  local bufs = meta.bufs ---@type dot.tab.IBufItem[]
  local bufid_next = stl.fn.navigate_circular(bufid_sourcefile, -step, #bufs) ---@type integer
  if bufid_sourcefile == bufid_next then
    return
  end

  local buf_sourcefile = bufs[bufid_sourcefile] ---@type dot.tab.IBufItem
  local buf_next = bufs[bufid_next] ---@type dot.tab.IBufItem

  ---! Don't swap the two buffers if their's pinned status not equal.
  if buf_sourcefile.pinned ~= buf_next.pinned then
    return
  end

  meta.bufs[bufid_next] = buf_sourcefile
  meta.bufs[bufid_sourcefile] = buf_next
  dot.state.status.dirtier_statusline:mark_dirty()
  dot.state.status.dirtier_tabline:mark_dirty()
end

---@param step                          ?integer
---@return nil
function M.swap_right(step)
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local meta = dot.tab.resolve(tabnr, false) ---@type dot.tab.IMeta|nil
  if meta == nil then
    stl.reporter.error({
      from = __module_name__,
      subject = "swap_right",
      message = "Cannot resolve the meta for the current tab.",
      details = { tabnr = tabnr },
    })
    return
  end

  local _, bufid_sourcefile = dot.tab.retrieve_buf_sourcefile(tabnr) ---@type dot.tab.IBufItem|nil, integer|nil
  if bufid_sourcefile == nil then
    return
  end

  step = math.max(1, step or vim.v.count1 or 1)
  local bufs = meta.bufs ---@type dot.tab.IBufItem[]
  local bufid_next = stl.fn.navigate_circular(bufid_sourcefile, step, #bufs) ---@type integer
  if bufid_sourcefile == bufid_next then
    return
  end

  local buf_sourcefile = bufs[bufid_sourcefile] ---@type dot.tab.IBufItem
  local buf_next = bufs[bufid_next] ---@type dot.tab.IBufItem

  ---! Don't swap the two buffers if their's pinned status not equal.
  if buf_sourcefile.pinned ~= buf_next.pinned then
    return
  end

  meta.bufs[bufid_next] = buf_sourcefile
  meta.bufs[bufid_sourcefile] = buf_next
  dot.state.status.dirtier_statusline:mark_dirty()
  dot.state.status.dirtier_tabline:mark_dirty()
end

return M
