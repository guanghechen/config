---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.fn.find_explorer" ---@type string

local Directory = require("era.view.directory")
local Jobs = require("era.m.filetree.jobs")
local paths = require("ux.filetree.path")
local surface = Directory.new()
local search_pattern = stl.c.Observable.from_value("")
local flag_fuzzy = stl.c.Observable.from_value(true)
local flag_regex = stl.c.Observable.from_value(false)
local flag_case_sensitive = stl.c.Observable.from_value(false)
local cwd = paths.from_os(dot.path.cwd())
local directory = cwd
local picker ---@type era.m.picker.BasicComposer
local scheduler ---@type stl.c.Scheduler
local observer ---@type stl.c.IUnsubscribable
local operation = false

---@param message                       any
---@return nil
local function report(message)
  stl.reporter.error({ from = __module_name__, message = tostring(message) })
end

---@return yoz.ux.filetree.Resource|nil
---@return boolean
local function current()
  return surface:retrieve(picker.result.lnum_current:snapshot())
end

---@return yoz.ux.filetree.Resource|nil
local function root()
  local frame = surface:frame()
  if frame and frame:source():node(frame:header().root.node) then
    return surface.data:inspect(frame:source(), frame:header().root.node)
  end
end

---@param path                          string
---@param focus                         ?string
---@return nil
local function open_directory(path, focus)
  surface:open(path, focus):finally(function(ok, resource)
    if ok and resource and not picker:isdisposed() then
      directory = resource:path()
      local relative = paths.relative(cwd, directory)
      picker.finder:set_title(relative == "." and "File explorer (cwd)" or "File explorer (" .. relative .. ")")
    end
  end)
end

---@param options                       table
---@param callback                      fun(input: string|nil): nil
---@return nil
local function prompt(options, callback)
  local winnr = picker.result:get_winnr()
  ---@return nil
  local function show()
    local row = vim.fn.line("w$") - vim.fn.line(".") <= 1 and -1 or 1
    vim.ui.input(vim.tbl_extend("force", { relative = "cursor", row = row, col = 4 }, options), callback)
  end
  if winnr and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_win_call(winnr, show)
  else
    show()
  end
end

---@param input                         ?string
---@return string|nil
local function entry_name(input)
  if input == nil then
    return nil
  end
  input = vim.trim(input)
  if input == "" or input == "." or input == ".." then
    report("Invalid name")
    return nil
  end
  if input:find("/", 1, true) or input:find("\\", 1, true) or input:find("%c") then
    report("Invalid name: path separator or control character is not allowed")
    return nil
  end
  return input
end

---@param plan                          ux.filetree.IOperationPlan|ux.filetree.ICreatePlan
---@param target                        ?string
---@param observed_root                 yoz.ux.filetree.Resource
---@param position                      {row: integer, sequence: integer}
---@return nil
local function run(plan, target, observed_root, position)
  if picker:isdisposed() then
    return
  end
  if operation then
    report("A file operation is already running")
    return
  end
  operation = true
  Jobs.run(surface.data, plan):finally(function(ok, result)
    operation = false
    if not ok then
      report(result)
      return
    end
    local item = result.items[1]
    if not result.success then
      if not result.status.cancelled then
        report(result.error or "Target already exists or operation was skipped")
      end
      return
    end
    if item.sync_error then
      report(item.sync_error.message)
    end
    stl.reporter.info({
      from = __module_name__,
      message = (plan.kind or "create") .. ": " .. (target or item.source or "done"),
    })
    local displayed = root()
    if displayed and displayed:node() == observed_root:node() then
      if surface.state:navigation_sequence() == position.sequence then
        surface:focus_path(target, position.row)
      end
      surface:refresh():catch(report)
      picker:mark_preview_dirty()
    end
  end)
end

---@return nil
local function create_entry()
  local selected, parent = current()
  local displayed = root()
  if not displayed then
    return
  end
  local destination = displayed
  local position = { row = picker.result.lnum_current:snapshot(), sequence = surface.state:navigation_sequence() }
  if selected and not parent then
    destination = selected:info().directory and selected
      or surface.data:inspect(selected:source(), selected:source():node(selected:node()).parent)
  end
  prompt({ prompt = "Create: " }, function(input)
    if input == nil then
      return
    end
    input = vim.trim(input)
    local is_directory = input:sub(-1) == "/"
    local name = entry_name(is_directory and input:sub(1, -2) or input)
    if name then
      run(
        { target = destination, path = name, directory = is_directory },
        paths.resolve(destination:path(), name),
        displayed,
        position
      )
    end
  end)
end

---@return nil
local function delete_entry()
  local selected, parent = current()
  local displayed = root()
  if not selected or not displayed then
    return
  end
  if parent then
    report("Cannot delete parent entry ../")
    return
  end
  local position = { row = picker.result.lnum_current:snapshot(), sequence = surface.state:navigation_sequence() }
  prompt({ prompt = "Delete '" .. selected:info().label .. "'? ", inputtype = "confirmation" }, function(answer)
    answer = answer and vim.trim(answer):lower()
    if answer == "y" or answer == "yes" then
      run({ kind = "delete", source = selected:source(), nodes = { selected:node() } }, nil, displayed, position)
    end
  end)
end

---@param kind                          "copy"|"move"
---@return nil
local function transfer(kind)
  local selected, parent = current()
  local displayed = root()
  if not selected or not displayed then
    return
  end
  if parent then
    report("Cannot " .. (kind == "copy" and "copy" or "rename") .. " parent entry ../")
    return
  end
  local source = selected:source()
  local position = { row = picker.result.lnum_current:snapshot(), sequence = surface.state:navigation_sequence() }
  local destination = surface.data:inspect(source, source:node(selected:node()).parent)
  local filename = paths.basename(selected:path())
  local suggested = filename
  if kind == "copy" then
    local ext = selected:info().directory and "" or paths.extname(filename)
    suggested = ext ~= "" and filename:sub(1, #filename - #ext) .. "-copy" .. ext or filename .. "-copy"
  end
  prompt({ prompt = kind == "copy" and "Copy as: " or "Rename to: ", default = suggested }, function(input)
    local name = entry_name(input)
    if name and name ~= filename then
      run({
        kind = kind,
        source = source,
        nodes = { selected:node() },
        target = destination,
        name = name,
        prepare_move = kind == "move",
      }, paths.resolve(destination:path(), name), displayed, position)
    end
  end)
end

---@return nil
local function confirm()
  local selected = current()
  if not selected then
    return
  end
  local path, info = selected:path(), selected:info()
  if info.directory then
    open_directory(path)
  elseif info.kind == "file" or info.target_kind == "file" then
    local tabnr = vim.api.nvim_get_current_tabpage()
    local winnr = dot.tab.retrieve_winnr_sourcefile(tabnr)
    picker:close()
    dot.win.open_filepath(winnr, path)
  end
end

---@return nil
local function copy_path()
  local selected = current()
  local winnr = picker.result:get_winnr()
  if selected and winnr and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_win_call(winnr, function()
      era.fn.select_copy_filepath({ filepath = selected:path(), relative = "cursor", row = 1, col = 4 })
    end)
  end
end

---@return nil
local function add_to_ai()
  local selected = current()
  if selected then
    era.fn.add_locations_to_ai({ { filepath = selected:path() } })
  end
end

---@param bufnr                         integer
---@return era.m.picker.preview.IDrawResult
local function preview_file(bufnr)
  local selected = current()
  local result = { title = "Preview", cursorline = false, number = false, wrap = false, whitespaces = true }
  local lines = { "No file selected" }
  if selected then
    local path, info = selected:path(), selected:info()
    result.title = paths.relative(cwd, path)
    if (info.kind == "file" or info.target_kind == "file") and stl.filetype.is_printable_file(info.label) then
      lines = stl.fs.read_file_as_lines({ filepath = paths.to_os(path), max_lines = 300, silent = true })
      vim.api.nvim_set_option_value("filetype", vim.filetype.match({ filename = path }) or "", { buf = bufnr })
      result.cursorline, result.number = true, true
    else
      lines = { "Not a text file, cannot preview." }
    end
  end
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  return result
end

local flags = {}
for _, entry in ipairs({
  { "fuzzy", flag_fuzzy, stl.icon.symbols.flag_fuzzy },
  { "sensitive", flag_case_sensitive, stl.icon.symbols.flag_case_sensitive },
  { "regex", flag_regex, stl.icon.symbols.flag_regex },
}) do
  flags[#flags + 1] = {
    desc = "Find Explorer: " .. entry[1],
    callback = function()
      entry[2]:next(not entry[2]:snapshot())
    end,
    snapshot = function()
      return entry[3], entry[2]:snapshot() and "picker_flag_blue" or "picker_flag_grey"
    end,
  }
end

---@type stl.t.IKeymap[]
local actions = {
  { modes = { "n", "x" }, key = "oa", desc = "filetree: create", callback = create_entry },
  { modes = { "n", "x" }, key = "od", desc = "filetree: delete", callback = delete_entry },
  { modes = { "n", "x" }, key = "oc", desc = "filetree: copy filepath", callback = copy_path },
  { modes = { "n", "x" }, key = "oA", desc = "filetree: add to ai", callback = add_to_ai },
  {
    modes = { "n", "x" },
    key = "c",
    desc = "filetree: copy as",
    callback = function()
      transfer("copy")
    end,
  },
  {
    modes = { "n", "x" },
    key = "or",
    desc = "filetree: rename",
    callback = function()
      transfer("move")
    end,
  },
  {
    modes = { "n", "x" },
    key = "<Backspace>",
    desc = "filetree: parent directory",
    callback = function()
      local displayed = root()
      local path = displayed and displayed:path() or directory
      open_directory(paths.dirname(path), path)
    end,
  },
}

picker = era.m.picker.BasicComposer.new({
  name = __module_name__,
  permanent = true,
  finder_title = "File explorer",
  height = 0.9,
  width = 0.9,
  search_pattern = search_pattern,
  flags = flags,
  result_number = false,
  result_tree = surface,
  keymaps_common = {
    { modes = { "i", "n", "x" }, key = "<Enter>", desc = "filetree: open", callback = confirm },
    { modes = { "i", "n", "x" }, key = "<Tab>", desc = "filetree: noop", callback = stl.fn.noop },
    {
      modes = { "i", "n", "x" },
      key = "<2-LeftMouse>",
      desc = "filetree: open",
      callback = function()
        if vim.fn.getmousepos().winid == picker.result:get_winnr() then
          confirm()
        end
      end,
    },
  },
  keymaps_finder = actions,
  keymaps_result = actions,
  render_result = function()
    surface:filter({
      pattern = search_pattern:snapshot(),
      fuzzy = flag_fuzzy:snapshot(),
      regex = flag_regex:snapshot(),
      case_sensitive = flag_case_sensitive:snapshot(),
    })
  end,
  render_preview = preview_file,
  preview_tree = function()
    local selected = current()
    if selected and selected:info().directory then
      return {
        owner = surface,
        key = selected:node(),
        title = paths.relative(cwd, selected:path()),
        foldempty = false,
        glyphs = { leaf = "", collapsed = "", expanded = "" },
      }
    end
  end,
  on_refresh = function()
    surface:refresh():catch(report)
    picker:mark_preview_dirty()
  end,
  on_disposed = function()
    observer:unsubscribe()
    scheduler:dispose()
    surface:dispose()
  end,
})

scheduler = stl.c.Scheduler.new({
  name = __module_name__ .. "#filter",
  mode = "debounce",
  delay = 64,
  timeout = 0,
  silent = stl.fn.falsy,
  value = stl.c.Observable.from_value(true),
  task = function()
    if not picker:isdisposed() then
      picker:mark_result_dirty()
      picker:mark_result_flags_dirty()
    end
  end,
})
observer = stl.fn.observe({ search_pattern, flag_fuzzy, flag_regex, flag_case_sensitive }, function()
  if not picker:isdisposed() then
    scheduler:schedule()
  end
end)

---@param specified_filepath            ?string
---@return nil
local function find_explorer(specified_filepath)
  cwd = paths.from_os(vim.fn.getcwd())
  local candidates = { specified_filepath or "" }
  local winnr = dot.tab.retrieve_winnr_sourcefile(vim.api.nvim_get_current_tabpage())
  if winnr and vim.api.nvim_win_is_valid(winnr) then
    candidates[#candidates + 1] = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(winnr))
  end
  local focus
  for _, candidate in ipairs(candidates) do
    if candidate ~= "" then
      candidate = paths.resolve(cwd, paths.from_os(candidate))
      local info = vim.uv.fs_stat(paths.to_os(candidate))
      if info then
        directory = info.type == "directory" and candidate or paths.dirname(candidate)
        focus = info.type ~= "directory" and candidate or nil
        break
      end
    end
  end
  open_directory(directory, focus)
  picker:focus()
end

return find_explorer
