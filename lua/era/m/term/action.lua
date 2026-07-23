local S = era.m.term

local __module_name__ = "era.m.term.action" ---@type string

---@type era.m.term.IProfile[]
local profiles = {
  { name = "shell", type = "shell", cmd = { vim.o.shell } },
}

---@param profile                       era.m.term.IProfile|nil
---@return nil
local function apply_profile(profile)
  if profile == nil then
    return
  end

  S.state.create({
    uuid = yoz.fn.uuid(),
    type = profile.type,
    name = profile.name,
    cmd = profile.cmd,
    permanent = false,
  })
  S.widget:focus()
end

---@param name                          string
---@param cwd                           string
---@param args                          ?string[]
---@return nil
local function open_lazygit(name, cwd, args)
  local cmd = vim.list_extend({ "lazygit" }, args or {}) ---@type string[]
  local termuuid = string.format("1c2b6245-da30-499a-8e23-8c33b5bd1a77#%s", name)

  S.widget:toggle_and_focus({
    uuid = termuuid,
    name = name,
    type = "lazygit",
    cmd = cmd,
    cwd = cwd,
    permanent = true,
    autofocus = true,
  })
end

---@param name                          string
---@param cwd                           string
---@param filepath                      string
---@return nil
local function open_yazi(name, cwd, filepath)
  local tempname = dot.path.locate_cache_filepath("yazi-chooser-files.txt") ---@type string

  local dirpath = dot.path.dirname(filepath) ---@type string
  local cmd = { "yazi", dirpath, "--chooser-file=" .. tempname } ---@type string[]
  S.widget:toggle_and_focus({
    uuid = string.format("69f6829d-c54a-46a2-8c52-5f2f2d40aa93#%s", name),
    name = name,
    type = "yazi",
    cmd = cmd,
    cwd = cwd,
    permanent = false,
    autofocus = true,
    on_closed = function()
      pcall(function()
        S.widget:close()

        local filepaths = vim.fn.filereadable(tempname) == 1 and vim.fn.readfile(tempname) or {} ---@type string[]
        filepaths = vim.tbl_filter(function(p)
          return vim.fn.filereadable(p) == 1
        end, filepaths)

        if #filepaths > 0 then
          dot.win.open_filepaths(nil, filepaths)
        end
      end)
    end,
  })
end

---@class era.m.term.action
local M = {}

---@return nil
function M.create()
  local profile_count = #profiles ---@type integer
  if profile_count == 1 then
    apply_profile(profiles[1])
    return
  end

  ---@type era.m.select.IItem[]
  local items = {}
  for index, profile in ipairs(profiles) do
    table.insert(items, {
      key = tostring(index),
      text = profile.name,
    })
  end

  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local mouse = vim.fn.getmousepos()

  era.m.select.open({
    title = "Select terminal profile",
    relative = "win",
    win = winnr,
    row = 0,
    col = mouse.wincol - 3,
    items = items,
    on_choice = function(selected_item)
      if selected_item == nil then
        return
      end

      local selected_index = tonumber(selected_item.key) ---@type integer|nil
      if selected_index == nil then
        return
      end

      local selected_profile = profiles[selected_index] ---@type era.m.term.IProfile|nil
      if selected_profile then
        apply_profile(selected_profile)
      end
    end,
  })
end

---@return nil
function M.destroy()
  local termindex = S.state.current() ---@type integer
  local _, termmeta = S.state.at(termindex) ---@type string|nil, era.m.term.IMeta|nil
  if termmeta == nil then
    stl.reporter.warn({
      from = __module_name__,
      subject = "destroy",
      message = "No active terminal found to destroy.",
    })
    return
  end

  vim.ui.input({
    inputtype = "confirmation",
    prompt = string.format("Delete the terminal (%s)? (y/N): ", termmeta.name),
    relative = "editor",
    row = 3,
    col = math.floor((vim.o.columns - 40) / 2),
  }, function(answer)
    if answer == nil then
      return
    end

    answer = vim.trim(answer:lower()) ---@type string
    if answer:sub(1, 1) ~= "y" then
      return
    end

    local next_termmeta = S.state.pick_next_term(termmeta.uuid) ---@type era.m.term.IMeta|nil
    if next_termmeta ~= nil then
      S.state.o_termuuid:next(next_termmeta.uuid)
    end

    vim.defer_fn(function()
      S.event.on_closed(termmeta)
      dot.state.status.dirtier_termline:mark_dirty()
    end, 100)
  end)
end

---@param step                          integer|nil
---@return nil
function M.focus_left(step)
  local N = S.state.size() ---@type integer
  local termuuid = S.state.o_termuuid:snapshot() ---@type string
  local index_current = S.state.indexof(termuuid) ---@type integer
  if index_current < 0 then
    return
  end

  step = math.max(1, step or vim.v.count1 or 1)
  local index_next = stl.fn.navigate_circular(index_current, -step, N) ---@type integer
  S.state.focus(index_next)
end

---@param step                          integer|nil
---@return nil
function M.focus_right(step)
  local N = S.state.size() ---@type integer
  local termuuid = S.state.o_termuuid:snapshot() ---@type string
  local index_current = S.state.indexof(termuuid) ---@type integer
  if index_current < 0 then
    return
  end

  step = math.max(1, step or vim.v.count1 or 1)
  local index_next = stl.fn.navigate_circular(index_current, step, N) ---@type integer
  S.state.focus(index_next)
end

---@return nil
function M.lazygit_cwd()
  local cwd = dot.path.cwd() ---@type string
  open_lazygit("lazygit", cwd)
end

---@return nil
function M.lazygit_file_history()
  local cwd = dot.path.cwd() ---@type string
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local args = { "-f", filepath } ---@type string[]
  open_lazygit("lazygit (file history)", cwd, args)
end

---@return nil
function M.rename()
  local termindex = S.state.current() ---@type integer
  local _, termmeta = S.state.at(termindex) ---@type string|nil, era.m.term.IMeta|nil
  if termmeta == nil then
    stl.reporter.warn({
      from = __module_name__,
      subject = "rename",
      message = "No active terminal found to rename.",
    })
    return
  end

  ---@type era.m.input.IOptions
  local input_opts = {
    prompt = "Enter new terminal name: ",
    default = termmeta.name,
  }

  local winnr = S.widget:get_winnr() ---@type integer|nil
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    local available_width = nil ---@type integer|nil
    local ok_width, width_value = pcall(vim.api.nvim_win_get_width, winnr)
    if ok_width and type(width_value) == "number" then
      available_width = width_value
    else
      local ok_cfg, cfg = pcall(vim.api.nvim_win_get_config, winnr)
      if ok_cfg and type(cfg) == "table" and type(cfg.width) == "number" then
        available_width = cfg.width
      end
    end

    if type(available_width) == "number" and available_width > 0 then
      local max_width = math.max(1, available_width - 2) ---@type integer
      local width = math.min(60, math.max(20, max_width)) ---@type integer
      width = math.min(width, max_width)
      local col = math.max(0, math.floor((available_width - width) / 2)) ---@type integer

      input_opts.relative = "win"
      input_opts.win = winnr
      input_opts.width = width
      input_opts.row = 1
      input_opts.col = col
    else
      input_opts.relative = "win"
      input_opts.win = winnr
      input_opts.row = 1
      input_opts.col = 0
    end
  end

  vim.ui.input(input_opts, function(new_name)
    if new_name == nil or #new_name == 0 then
      return
    end

    if new_name == termmeta.name then
      return
    end

    S.state.update(termmeta, { name = new_name })
    dot.state.status.dirtier_termline:mark_dirty()
  end)
end

---@param step                          integer|nil
---@return nil
function M.swap_left(step)
  local index_current, termuuid_current = S.state.current() ---@type integer, string|nil
  if termuuid_current == nil then
    return
  end

  step = math.max(1, step or vim.v.count1 or 1)
  local N = S.state.size() ---@type integer
  local index_next = stl.fn.navigate_circular(index_current, -step, N) ---@type integer
  local termuuid_next = S.state.at(index_next) ---@type string|nil

  if termuuid_next == nil or termuuid_next == termuuid_current then
    return
  end

  S.state.put(index_current, termuuid_next)
  S.state.put(index_next, termuuid_current)
  dot.state.status.dirtier_termline:mark_dirty()
end

---@param step                          integer|nil
---@return nil
function M.swap_right(step)
  local index_current, termuuid_current = S.state.current() ---@type integer, string|nil
  if termuuid_current == nil then
    return
  end

  step = math.max(1, step or vim.v.count1 or 1)
  local N = S.state.size() ---@type integer
  local index_next = stl.fn.navigate_circular(index_current, step, N) ---@type integer
  local termuuid_next = S.state.at(index_next) ---@type string|nil

  if termuuid_next == nil or termuuid_next == termuuid_current then
    return
  end

  S.state.put(index_current, termuuid_next)
  S.state.put(index_next, termuuid_current)
  dot.state.status.dirtier_termline:mark_dirty()
end

---@return nil
function M.toggle()
  local termindex = S.state.current() ---@type integer
  local _, termmeta_current = S.state.at(termindex) ---@type string|nil, era.m.term.IMeta|nil
  local is_shell_or_runner = termmeta_current ~= nil
    and (termmeta_current.type == "runner" or termmeta_current.type == "shell")

  if S.widget:isvisible() then
    if is_shell_or_runner then
      S.widget:toggle()
      return
    end
  else
    S.widget:focus()
    if is_shell_or_runner then
      return
    end
  end

  local _, termmeta_shell = S.state.find_index_by_type("shell") ---@type integer, era.m.term.IMeta|nil
  local selected_text = stl.nvim.buf.retrieve_selected_text() ---@type string
  if termmeta_shell == nil then
    S.widget:toggle_and_focus({
      uuid = yoz.fn.uuid(),
      type = "shell",
      name = "shell",
      cwd = dot.path.cwd(),
      autofocus = true,
      permanent = true,
      selected_text = selected_text,
    })
  else
    S.widget:toggle_and_focus({
      uuid = termmeta_shell.uuid,
      type = termmeta_shell.type,
      name = termmeta_shell.name,
      cwd = termmeta_shell.cwd,
      autofocus = true,
      permanent = true,
      selected_text = selected_text,
    })
  end
end

---@return nil
function M.yazi_cwd()
  local cwd = dot.path.cwd() ---@type string
  open_yazi("yazi_cwd", cwd, cwd)
end

---@return nil
function M.yazi_reveal()
  local cwd = dot.path.cwd() ---@type string
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local bufnr_sourcefile = dot.tab.retrieve_bufnr_sourcefile(tabnr) ---@type integer|nil
  if bufnr_sourcefile == nil then
    open_yazi("yazi_cwd", cwd, cwd)
  else
    local filepath = vim.api.nvim_buf_get_name(bufnr_sourcefile) ---@type string
    open_yazi("yazi_cwd", cwd, filepath)
  end
end

---@return nil
function M.yazi_workspace()
  local workspace = dot.path.workspace() ---@type string
  open_yazi("yazi_workspace", workspace, workspace)
end

return M
