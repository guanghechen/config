local btn = eve.nvim.btn
local txt = eve.nvim.txt

---@type string
local fn_switch_term = eve.G.register_anonymous_fn(function(bufnr)
  eve.term.o_bufnr:next(bufnr) ---@type integer
end) or ""

---@class eve.ux.nvimbar.component.term
local M = {}

---@param position                      eve.ux.nvimbar.PositionEnum
---@return eve.ux.nvimbar.IRawComponent
function M.terms(position)
  local hln_term_index = position .. "_term_index" ---@type string
  local hln_term_name = position .. "_term_name" ---@type string
  local hln_term_sep_left = position .. "_term_sep_left" ---@type string
  local hln_term_sep_right = position .. "_term_sep_right" ---@type string

  local hln_termc_index = position .. "_termc_index" ---@type string
  local hln_termc_name = position .. "_termc_name" ---@type string
  local hln_termc_sep_middle = position .. "_termc_sep_middle" ---@type string
  local hln_termc_sep_left = position .. "_termc_sep_left" ---@type string
  local hln_termc_sep_right = position .. "_termc_sep_right" ---@type string

  local text_sep_left = eve.icon.symbols.sep_left ---@type string
  local text_sep_middle = " | " ---@type string
  local text_sep_right = eve.icon.symbols.sep_right ---@type string

  ---@param term                        eve.builtin.term.IMeta
  ---@param index                       integer
  ---@return string
  ---@return string
  local function render_term(term, index)
    -- Truncate long terminal names for better display
    local text_name = term.name ---@type string
    if #text_name > 12 then
      text_name = string.sub(text_name, 1, 9) .. "..."
    end

    local text_index = tostring(index) ---@type string
    text_name = text_name .. " "
    text_index = " " .. text_index

    local hl_text_index = txt(text_index, hln_term_index)
    local hl_text_name = txt(text_name, hln_term_name)
    local hl_text_sep_left = txt(text_sep_left, hln_term_sep_left)
    local hl_text_sep_right = txt(text_sep_right, hln_term_sep_right)

    local text = text_sep_left .. text_name .. text_index .. text_sep_right
    local hl_text = hl_text_sep_left .. hl_text_name .. hl_text_index .. hl_text_sep_right
    return text, btn(hl_text, fn_switch_term, term.bufnr)
  end

  ---@param term                        eve.builtin.term.IMeta
  ---@param index                       integer
  ---@return string
  ---@return string
  local function render_termc(term, index)
    -- Truncate long terminal names for better display
    local text_name = term.name ---@type string
    if #text_name > 12 then
      text_name = string.sub(text_name, 1, 9) .. "..."
    end

    local text_index = tostring(index) ---@type string

    local hl_text_index = txt(text_index, hln_termc_index)
    local hl_text_name = txt(text_name, hln_termc_name)
    local hl_text_sep_left = txt(text_sep_left, hln_termc_sep_left)
    local hl_text_sep_middle = txt(text_sep_middle, hln_termc_sep_middle)
    local hl_text_sep_right = txt(text_sep_right, hln_termc_sep_right)

    local text = text_sep_left .. text_name .. text_sep_middle .. text_index .. text_sep_right
    local hl_text = hl_text_sep_left .. hl_text_name .. hl_text_sep_middle .. hl_text_index .. hl_text_sep_right
    return text, btn(hl_text, fn_switch_term, term.bufnr)
  end

  ---@type eve.ux.nvimbar.IRawComponent
  local component = {
    name = "term:terms",
    atomic = false,
    render = function(_, remain_width)
      local term_bufnr_current = eve.term.o_bufnr:snapshot() ---@type integer|nil
      if term_bufnr_current == nil or term_bufnr_current < 1 or not vim.api.nvim_buf_is_valid(term_bufnr_current) then
        return "", "", false
      end

      local text = " " ---@type string
      local hl_text = " " ---@type string
      local index = 0 ---@type integer
      for termmeta in eve.term:iterator() do
        if termmeta ~= nil then
          index = index + 1 ---@type integer
          local render = termmeta.bufnr == term_bufnr_current and render_termc or render_term
          local t, ht = render(termmeta, index)
          local w = vim.api.nvim_strwidth(t) ---@type integer
          if remain_width < w then
            break
          end

          text = text .. t .. " "
          hl_text = hl_text .. ht .. " "
          remain_width = remain_width - w
        end
      end

      if index == 0 then
        return "", "", false
      end
      return text, hl_text, true
    end,
  }
  return component
end

return M
