local Popup = require("nui.popup")
local Layout = require("nui.layout")
local util_navigator = require("guanghechen.util.navigator")

---@alias guanghechen.replacer.IStateKey
---|"flag_ignore_case"
---|"flag_multileline"
---|"flag_regex"
---|"search_excludes"
---|"search_includes"
---|"search_paths"
---|"search_text"
---|"replace_text"

---@class guanghechen.replacer.IState
---@field public flag_ignore_case boolean
---@field public flag_multileline boolean
---@field public flag_regex boolean
---@field public search_excludes string
---@field public search_includes string
---@field public search_paths string
---@field public search_text string
---@field public replace_text string

---@class guanghechen.replace.ITab
---@field public tabnr number
---@field public winnr1 number
---@field public winnr2 number
---@field public winnr3 number
---@field public bufnr1 number
---@field public bufnr2 number
---@field public bufnr3 number

---@class guanghechen.replacer.IPopup
---@field public key guanghechen.replacer.IStateKey
---@field public popup any
---@field public get_value fun():string

---@class guanghechen.replacer.IPopupOptions
---@field key guanghechen.replacer.IStateKey
---@field title string
---@field initial_value string
---@field enter boolean|nil
---@field focus_next fun():nil
---@field focus_prev fun():nil
---@field on_concel fun():nil
---@field on_confirm fun():nil

---@class guanghechen.replacer.IOptions
---@field public state guanghechen.replacer.IState
---@field public on_change fun(next_state:guanghechen.replacer.IState):nil

---@class guanghechen.replacer.Popup : guanghechen.replacer.IPopup
local ReplacerPopup = {}
ReplacerPopup.__index = ReplacerPopup

---@param opts guanghechen.replacer.IPopupOptions
function ReplacerPopup.new(opts)
  local self = setmetatable({}, ReplacerPopup)

  local key = opts.key ---@type guanghechen.replacer.IStateKey
  local title = opts.title ---@type string
  local initial_value = opts.initial_value ---@type string
  local enter = opts.enter ---@type boolean|nil
  local focus_prev = opts.focus_prev
  local focus_next = opts.focus_next
  local on_concel = opts.on_concel
  local on_confirm = opts.on_confirm

  local popup = Popup({
    enter = enter,
    focusable = true,
    border = {
      style = "rounded",
      text = {
        top = title,
        top_align = "center",
      },
      padding = {
        top = 0,
        bottom = 0,
        left = 1,
        right = 1,
      },
    },
    buf_options = {
      filetype = "ghc_replace",
      modifiable = true,
      readonly = false,
    },
    win_options = {
      winblend = 10,
      winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
    },
  })

  self.key = key
  self.popup = popup

  ---@return string
  function self.get_value()
    local lines = vim.api.nvim_buf_get_lines(popup.bufnr, 0, -1, false) ---@type string[]
    local value = table.concat(lines, "\n") ---@type string
    return value
  end

  popup:map("n", "q", on_concel, { noremap = true, silent = true, desc = "Cancel" })
  popup:map("n", "<cr>", on_confirm, { noremap = true, silent = true, desc = "Confirm" })
  popup:map("n", "<s-tab>", focus_prev, { noremap = true, silent = true, desc = "Focus previous" })
  popup:map("n", "<tab>", focus_next, { noremap = true, silent = true, desc = "Focus next" })
  vim.api.nvim_buf_set_lines(popup.bufnr, 0, 1, false, { initial_value })
  return self
end

---@class guanghechen.replacer.Replacer
---@field public state guanghechen.replacer.IState
---@field public tab guanghechen.replace.ITab|nil
---@field public layout any|nil
---@field private on_change fun(next_state:guanghechen.replacer.IState):nil
local Replacer = {}
Replacer.__index = Replacer

---@param opts guanghechen.replacer.IOptions
---@return guanghechen.replacer.Replacer
function Replacer.new(opts)
  local self = setmetatable({}, Replacer)

  ---@type guanghechen.replacer.IState
  local state = {
    flag_ignore_case = opts.state.flag_ignore_case, ---@type boolean
    flag_multileline = opts.state.flag_multileline, ---@type boolean
    flag_regex = opts.state.flag_regex, ---@type boolean
    search_excludes = opts.state.search_excludes, ---@type string
    search_includes = opts.state.search_includes, ---@type string
    search_paths = opts.state.search_paths, ---@type string
    search_text = opts.state.search_text, ---@type string
    replace_text = opts.state.replace_text, ---@type string
  }

  self.state = state
  self.tab = nil
  self.on_change = opts.on_change
  self.layout = nil
  return self
end

function Replacer:destroy()
  if self.layout ~= nil then
    self.layout:unmount()
    self.layout = nil
  end
end

function Replacer:edit()
  if self.layout ~= nil then
    self.layout:show()
    return
  end

  local popups = {} ---@type guanghechen.replacer.IPopup[]

  local function focus_prev(index)
    return function()
      local step = vim.v.count1 or 1
      local popup_idx = util_navigator.navigate_circular(index, -step, #popups)
      local popup = popups[popup_idx]
      vim.api.nvim_set_current_win(popup.popup.winid)
    end
  end

  local function focus_next(index)
    return function()
      local step = vim.v.count1 or 1
      local popup_idx = util_navigator.navigate_circular(index, step, #popups)
      local popup = popups[popup_idx]
      vim.api.nvim_set_current_win(popup.popup.winid)
    end
  end

  local function on_cancel()
    self.layout:hide()
  end

  local function on_confirm()
    local has_changed = false ---@type boolean
    local next_state = vim.tbl_deep_extend("force", {}, self.state) ---@type guanghechen.replacer.IState

    ---@diagnostic disable-next-line: unused-local
    for index, popup in ipairs(popups) do
      local key = popup.key ---@type string
      local initial_value = self.state[key]
      local value = popup.get_value()
      if value ~= initial_value then
        has_changed = true
        next_state[key] = value
      end
    end

    if has_changed then
      self.state = next_state
      self.on_change(next_state)
    end
    self.layout:hide()
  end

  ---@param index number
  ---@param key guanghechen.replacer.IStateKey
  ---@param title string
  ---@param initial_value string
  ---@param enter? boolean
  local function create_popup(index, key, title, initial_value, enter)
    local popup = ReplacerPopup.new({
      key = key,
      title = title,
      initial_value = initial_value,
      enter = enter,
      focus_prev = focus_prev(index),
      focus_next = focus_next(index),
      on_concel = on_cancel,
      on_confirm = on_confirm,
    })
    return popup
  end

  local search_text_popup = create_popup(1, "search_text", "Search", self.state.search_text, true)
  local replace_text_popup = create_popup(2, "replace_text", "Replace", self.state.replace_text, false)
  local search_paths_popup = create_popup(3, "search_paths", "Search Paths", self.state.search_paths, false)
  local search_include_popup = create_popup(4, "search_includes", "Search Includes", self.state.search_includes, false)
  local search_exclude_popup = create_popup(5, "search_excludes", "Search Excludes", self.state.search_excludes, false)

  table.insert(popups, search_text_popup)
  table.insert(popups, replace_text_popup)
  table.insert(popups, search_paths_popup)
  table.insert(popups, search_include_popup)
  table.insert(popups, search_exclude_popup)

  local boxses = {
    Layout.Box(search_text_popup.popup, { grow = 1, size = 3 }),
    Layout.Box(replace_text_popup.popup, { grow = 1, size = 3 }),
    Layout.Box(search_paths_popup.popup, { grow = 1, size = 3 }),
    Layout.Box(search_include_popup.popup, { grow = 1, size = 3 }),
    Layout.Box(search_exclude_popup.popup, { grow = 1, size = 3 }),
  }

  local layout = Layout({
    relative = "editor",
    position = "50%",
    size = {
      width = 100,
      height = 25,
    },
  }, Layout.Box(boxses, { dir = "col" }))

  self.layout = layout
  layout:mount()
end

function Replacer:toggle_tab()
  if self.tab ~= nil then
    vim.api.nvim_set_current_tabpage(self.tab.tabnr)
    return
  end

  vim.cmd("tabnew")
  local winnr1 = vim.api.nvim_get_current_win() ---@type number

  local win1_config = vim.api.nvim_win_get_config(winnr1)
  local rows = win1_config.height ---@type number
  local cols = win1_config.width ---@type number

  vim.cmd("vsplit")
  local winnr3 = vim.api.nvim_get_current_win() ---@type number

  vim.cmd("wincmd h")
  vim.cmd("split")
  local winnr2 = vim.api.nvim_get_current_win() ---@type number

  local bufnr1 = vim.api.nvim_create_buf(false, true)
  local bufnr2 = vim.api.nvim_create_buf(false, true)
  local bufnr3 = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_win_set_buf(winnr1, bufnr1)
  vim.api.nvim_win_set_buf(winnr2, bufnr2)
  vim.api.nvim_win_set_buf(winnr3, bufnr3)

  local width_left = math.min(40, math.floor(cols * 0.3)) ---@type number
  local height_left_top = math.min(30, math.floor(rows * 0.3)) ---@type number
  vim.api.nvim_win_set_config(winnr1, { width = width_left, height = height_left_top })
  vim.api.nvim_win_set_config(winnr2, { width = width_left, height = rows - height_left_top })
  vim.api.nvim_win_set_config(winnr3, { width = cols - width_left, height = rows })

  -- Make the buffer not editable
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr1 })
  vim.api.nvim_set_option_value("readonly", true, { buf = bufnr1 })
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr2 })
  vim.api.nvim_set_option_value("readonly", true, { buf = bufnr2 })
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr3 })
  vim.api.nvim_set_option_value("readonly", true, { buf = bufnr3 })

  local tabnr = vim.api.nvim_get_current_tabpage()
  self.tab = {
    tabnr = tabnr,
    winnr1 = winnr1,
    winnr2 = winnr2,
    winnr3 = winnr3,
    bufnr1 = bufnr1,
    bufnr2 = bufnr2,
    bufnr3 = bufnr3,
  }
  vim.api.nvim_create_autocmd({ "TabLeave" }, {
    callback = function()
      if self.tab ~= nil and vim.api.nvim_get_current_tabpage() == self.tab.tabnr then
        self.tab = nil
      end
    end,
  })
end

function Replacer:close_tab()
  if self.tab ~= nil then
    vim.cmd("tabclose")
    self.tab = nil
  end
end

------------test-------------
local replacer = Replacer.new({
  state = {
    flag_ignore_case = false,
    flag_multileline = false,
    flag_regex = false,
    search_text = "hello",
    search_paths = "",
    search_excludes = "node_modules/",
    search_includes = "lua/",
    replace_text = "world",
  },
  on_change = function(next_state)
    vim.notify("next state:\n" .. vim.inspect(next_state))
  end,
})

-- replacer:edit()
replacer:toggle_tab()
