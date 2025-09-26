local name = "fml.action.search.buffer" ---@type string
local title = "Search in Buffer" ---@type string

---@class fml.action.search.buffer.IState
---@field public bufnr                     integer
---@field public winnr                     integer
---@field public search_pattern            string
---@field public matches                   oxi.string.ILineMatch[]
---@field public nsnr_search               integer
---@field public popup_bufnr               integer|nil
---@field public popup_winnr               integer|nil

local current_state = nil ---@type fml.action.search.buffer.IState|nil

---@param bufnr                           integer
---@return nil
local function clear_highlights(bufnr)
  if current_state and current_state.nsnr_search then
    vim.api.nvim_buf_clear_namespace(bufnr, current_state.nsnr_search, 0, -1)
  end
end

---@param bufnr                           integer
---@param matches                         oxi.string.ILineMatch[]
---@param nsnr                            integer
---@return nil
local function apply_highlights(bufnr, matches, nsnr)
  clear_highlights(bufnr)

  for _, match in ipairs(matches) do
    local row = match.lnum - 1 ---@type integer
    for _, point in ipairs(match.matches) do
      vim.hl.range(bufnr, nsnr, "Search", { row, point.l }, { row, point.r })
    end
  end
end

---@param pattern                         string
---@return nil
local function perform_search(pattern)
  if not current_state then
    return
  end

  current_state.search_pattern = pattern

  if pattern == "" then
    clear_highlights(current_state.bufnr)
    current_state.matches = {}
    return
  end

  local matches = oxi.searcher.search_in_buffer(pattern, current_state.bufnr, false, false)
  if matches then
    current_state.matches = matches
    apply_highlights(current_state.bufnr, matches, current_state.nsnr_search)
  else
    current_state.matches = {}
    clear_highlights(current_state.bufnr)
  end
end

---@return nil
local function close_popup()
  if current_state then
    if current_state.popup_winnr and vim.api.nvim_win_is_valid(current_state.popup_winnr) then
      vim.api.nvim_win_close(current_state.popup_winnr, true)
    end

    clear_highlights(current_state.bufnr)

    -- Clear sign from popup buffer
    if current_state.popup_bufnr and vim.api.nvim_buf_is_valid(current_state.popup_bufnr) then
      pcall(vim.fn.sign_unplace, "fml_search_buffer_prompt", { buffer = current_state.popup_bufnr })
    end

    current_state = nil
  end
end

---@return nil
local function create_popup()
  if current_state then
    close_popup()
  end

  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local winnr = vim.api.nvim_get_current_win() ---@type integer

  if not vim.api.nvim_buf_is_valid(bufnr) then
    std.reporter.warn({
      from = name,
      message = "Invalid buffer for search",
    })
    return
  end

  local nsnr_search = vim.api.nvim_create_namespace("fml.action.search.buffer") ---@type integer

  current_state = {
    bufnr = bufnr,
    winnr = winnr,
    search_pattern = "",
    matches = {},
    nsnr_search = nsnr_search,
    popup_bufnr = nil,
    popup_winnr = nil,
  }

  -- Create popup buffer
  local popup_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_buf_set_lines(popup_bufnr, 0, -1, false, { "" })

  -- Calculate popup position (top-center)
  local ui = vim.api.nvim_list_uis()[1] ---@type table
  local width = math.min(50, math.floor(ui.width * 0.8)) ---@type integer
  local height = 1 ---@type integer
  local row = 2 ---@type integer
  local col = math.floor((ui.width - width) / 2) ---@type integer

  -- Create popup window
  local popup_winnr = vim.api.nvim_open_win(popup_bufnr, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = string.format(" %s ", title),
    title_pos = "center",
  })

  current_state.popup_bufnr = popup_bufnr
  current_state.popup_winnr = popup_winnr

  -- Set popup options
  vim.api.nvim_set_option_value("winhl", "Normal:Normal,FloatBorder:FloatBorder", { win = popup_winnr })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = popup_bufnr })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = popup_bufnr })
  vim.wo[popup_winnr].signcolumn = "yes"

  -- Set up search icon sign
  local sign_group = "fml_search_buffer_prompt"
  local sign_name = "SearchBufferPrompt"
  vim.fn.sign_define(sign_name, { text = eve.icon.ui.Search, texthl = "f_pk_finder_prompt" })
  vim.fn.sign_place(1, sign_group, sign_name, popup_bufnr, { lnum = 1, priority = 10 })

  -- Set up input callback for real-time search
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = popup_bufnr,
    callback = function()
      local lines = vim.api.nvim_buf_get_lines(popup_bufnr, 0, -1, false)
      if #lines > 0 then
        local line = lines[1] ---@type string
        perform_search(line)
      end
    end,
  })

  -- Key mappings
  ---@type std.t.IKeymap[]
  local keymaps = {
    {
      modes = { "n" },
      key = "q",
      desc = "Close search popup",
      callback = close_popup,
    },
    {
      modes = { "n", "i" },
      key = "<C-n>",
      desc = "Go to first match",
      callback = function()
        if current_state and #current_state.matches > 0 then
          local first_match = current_state.matches[1]
          vim.api.nvim_win_set_cursor(current_state.winnr, { first_match.lnum, first_match.matches[1].l })
          vim.api.nvim_set_current_win(current_state.winnr)
        end
      end,
    },
    {
      modes = { "n", "i" },
      key = "<CR>",
      desc = "Close search and clear highlights",
      callback = close_popup,
    },
  }

  eve.nvim.bindkeys(keymaps, { bufnr = popup_bufnr, noremap = true, silent = true })

  -- Auto-close when leaving the popup
  vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
    buffer = popup_bufnr,
    once = true,
    callback = function()
      vim.schedule(function()
        if
          current_state
          and current_state.popup_winnr
          and vim.api.nvim_get_current_win() ~= current_state.popup_winnr
        then
          close_popup()
        end
      end)
    end,
  })

  -- Focus the popup and enter insert mode
  vim.api.nvim_set_current_win(popup_winnr)
  vim.cmd("startinsert!")
end

---@class fml.action.search.buffer
local M = {}

---@return nil
function M.search_in_buffer()
  create_popup()
end

---@return nil
function M.close_search()
  close_popup()
end

return M

