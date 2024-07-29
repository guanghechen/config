local std_array = require("fml.std.array")
local box = require("fml.std.box")
local reporter = require("fml.report")
local util = require("fml.std.util")

---@class fml.ui2.Textarea
---@field protected bufnr               integer|nil
---@field protected winnr               integer|nil
---@field protected position            fml.enums.BoxPosition
---@field protected height              number
---@field protected width               number
---@field protected max_width           number|nil
---@field protected max_height          number|nil
---@field protected min_width           number|nil
---@field protected min_height          number|nil
---@field protected title               string
---@field protected filetype            string|nil
---@field protected keymaps             fml.types.IKeymap[]
local M = {}

---@class fml.ui2.textarea.IProps
---@field public position               fml.enums.BoxPosition
---@field public height                 number
---@field public width                  number
---@field public title                  string
---@field public max_width              ?number
---@field public max_height             ?number
---@field public min_width              ?number
---@field public min_height             ?number
---@field public filetype               ?string
---@field public keymaps                ?fml.types.IKeymap[]
---@field public validate               fun(text: string): string|nil
---@field public on_close               fun(): nil
---@field public on_confirm             fun(text: string): nil

---@class fml.ui2.textarea.IOpenParams
---@field public initial_text           string
---@field public row                    ?number
---@field public col                    ?number
---@field public cursor_row             ?integer
---@field public cursor_col             ?integer
---@field public text_cursor_row        ?integer
---@field public text_cursor_col        ?integer

---@param props                         fml.ui2.textarea.IProps
---@return fml.ui2.Textarea
function M.new(props)
  local self = setmetatable({}, M)

  local position = props.position ---@type fml.enums.BoxPosition
  local width = props.width ---@type number
  local height = props.height ---@type number
  local max_width = props.max_width ---@type number
  local max_height = props.max_height ---@type number
  local min_width = props.min_width ---@type number
  local min_height = props.min_height ---@type number
  local filetype = props.filetype ---@type string
  local keymaps = props.keymaps or {} ---@type fml.types.IKeymap[]
  local title = props.title ---@type string|nil
  title = (type(title) == "string" and #title > 0) and "" or (" " .. title .. " ") ---@type string

  local validate = props.validate ---@type fun(text: string): string|nil
  local on_close_from_props = props.on_close ---@type fun(): nil
  local on_confirm_from_props = props.on_confirm ---@type fun(text: string): nil

  ---@return nil
  local function on_close()
    self:close()
    on_close_from_props()
  end

  ---@return nil
  local function on_confirm()
    if self.bufnr == nil or not vim.api.nvim_buf_is_valid(self.bufnr) then
      reporter.warn({
        from = "fml.ui.textarea",
        subject = "confirm",
        message = "The buffer is not valid.",
        details = { bufnr = self.bufnr, self = self },
      })
      return
    end

    local lines = vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, false) ---@type string[]
    local text = table.concat(lines, "\n") ---@type string
    local err_msg = validate(text)
    if err_msg ~= nil then
      reporter.info({
        from = "fml.ui.textarea",
        subject = "confirm",
        message = "Validation failed.",
        details = { text = text, err_msg = err_msg },
      })
      return
    end

    self:close()
    on_confirm_from_props(text)
  end

  ---@type fml.types.IKeymap[]
  local builtin_keymaps = {
    { modes = { "n" }, key = "q", desc = "textarea: quit", callback = on_close },
    { modes = { "i", "n", "v" }, key = "<cr>", desc = "textarea: confirm", callback = on_confirm },
  }
  keymaps = std_array.concat(keymaps, builtin_keymaps)

  self.bufnr = nil
  self.winnr = nil
  self.position = position
  self.height = height
  self.width = width
  self.max_width = max_width
  self.max_height = max_height
  self.min_width = min_width
  self.min_height = min_height
  self.filetype = filetype
  self.keymaps = keymaps
  self.title = title

  return self
end

---@param params                        fml.ui2.textarea.IOpenParams
---@return nil
function M:open(params)
  local rect = box.measure({
    position = self.position,
    width = self.width,
    height = self.height,
    row = params.row,
    col = params.col,
    cursor_row = params.cursor_row,
    cursor_col = params.cursor_col,
    max_width = self.max_width,
    max_height = self.max_height,
    min_width = self.min_width,
    min_height = self.min_height,
  })

  local text_cursor_row = params.text_cursor_row or 1 ---@type integer
  local text_cursor_col = params.text_cursor_col or 1 ---@type integer

  if self.bufnr == nil or not vim.api.nvim_buf_is_valid(self.bufnr) then
    local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
    self.bufnr = bufnr

    vim.bo[bufnr].buflisted = false
    vim.bo[bufnr].buftype = "nofile"
    vim.bo[bufnr].filetype = self.filetype
    vim.bo[bufnr].swapfile = false
    util.bind_keys(self.keymaps, { bufnr = bufnr, noremap = true, silent = true })

    vim.schedule(function()
      vim.cmd("stopinsert")
    end)
  end

  if self.winnr == nil or not vim.api.nvim_win_is_valid(self.winnr) then
    ---@type integer
    local winnr = vim.api.nvim_open_win(self.bufnr, true, {
      relative = "editor",
      anchor = "NW",
      row = rect.row,
      col = rect.col,
      width = rect.width,
      height = rect.height,
      focusable = true,
      title = self.title,
      border = "rounded",
      style = "minimal",
    })
    self.winnr = winnr

    vim.wo[winnr].number = true
    vim.wo[winnr].relativenumber = true
    vim.api.nvim_win_set_cursor(self.winnr, { text_cursor_row, text_cursor_col })
  end
end

---@return nil
function M:close()
  if self.winnr ~= nil and vim.api.nvim_win_is_valid(self.winnr) then
    vim.api.nvim_win_close(self.winnr, true)
  end

  if self.bufnr ~= nil and vim.api.nvim_buf_is_valid(self.bufnr) then
    vim.api.nvim_buf_delete(self.bufnr, { force = true })
  end

  self.bufnr = nil
  self.winnr = nil
end

return M
