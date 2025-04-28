---@class fml.dressing.indentline.IState
---@field public winnr                  integer
---@field public bufnr                  integer
---@field public changedtick            integer
---
---@field public top                    integer
---@field public bottom                 integer
---@field public leftcol                integer
---
---@field public breakindent            boolean
---@field public shiftwidth             integer
---
---@field public indents                table<integer, integer>
---@field public blanks                 table<integer, boolean>

local extmarks_cachemap = {} ---@type table<string, vim.api.keyset.set_extmark[]>
local state_map = {} ---@type table<integer, fml.dressing.indentline.IState>

---@param winnr                         integer
---@param bufnr                         integer
---@param top                           integer
---@param bottom                        integer
---@return fml.dressing.indentline.IState
local function get_state(winnr, bufnr, top, bottom)
  local state_prev = state_map[winnr] ---@type fml.dressing.indentline.IState|nil
  local changedtick = vim.api.nvim_buf_get_changedtick(bufnr) ---@type integer
  if state_prev == nil or state_prev.bufnr ~= bufnr or state_prev.changedtick ~= changedtick then
    state_prev = nil
  end

  local ret = vim.api.nvim_buf_call(bufnr, vim.fn.winsaveview) ---@type vim.fn.winsaveview.ret
  local leftcol = ret.leftcol or 0 ---@type integer

  local breakindent = vim.wo[winnr].breakindent and vim.wo[winnr].wrap ---@type boolean
  local shiftwidth = vim.bo[bufnr].shiftwidth or vim.o.shiftwidth ---@type integer
  shiftwidth = shiftwidth == 0 and vim.bo[bufnr].tabstop or shiftwidth

  local indents = state_prev and state_prev.indents or { [0] = 0 } ---@type table<integer, integer>
  local blanks = state_prev and state_prev.blanks or {} ---@type table<integer, boolean>

  ---@type fml.dressing.indentline.IState
  local state = {
    winnr = winnr,
    bufnr = bufnr,
    changedtick = changedtick,

    top = top,
    bottom = bottom,
    leftcol = leftcol,

    breakindent = breakindent,
    shiftwidth = shiftwidth,

    indents = indents,
    blanks = blanks,
  }
  state_map[winnr] = state
  return state
end

--- Get the virtual text for the indent guide with
--- the given indent level, left column and shiftwidth
---@param indent                        integer
---@param state                         fml.dressing.indentline.IState
---@return vim.api.keyset.set_extmark[]
local function get_extmarks(indent, state)
  local key = string.format("%d:%d:%d:%s", indent, state.leftcol, state.shiftwidth, (state.breakindent and "bi" or ""))
  if extmarks_cachemap[key] then
    return extmarks_cachemap[key]
  end

  local offset = 0 ---@type integer
  local sw = state.shiftwidth
  indent = math.floor(indent / sw) -- full visible indents

  extmarks_cachemap[key] = {}
  for i = 1 + offset, indent do
    local col = (i - 1) * sw - state.leftcol
    if col >= 0 then
      local level = (i - 1) % 8 ---@type integer
      local hlname = "indentline_" .. level ---@type string
      table.insert(extmarks_cachemap[key], {
        virt_text = { { "│", hlname } },
        virt_text_pos = "overlay",
        virt_text_win_col = col,
        hl_mode = "combine",
        priority = 1,
        ephemeral = true,
        virt_text_repeat_linebreak = state.breakindent,
      })
    end
  end
  return extmarks_cachemap[key]
end

local nsnr = eve.var.nsnr.indentline ---@type integer
vim.api.nvim_set_decoration_provider(nsnr, {
  on_win = function(_, winnr, bufnr, top, bottom)
    local filetype = vim.bo[bufnr].filetype ---@type string
    if eve.filetype.is_not_indentline(filetype) then
      return
    end

    local state = get_state(winnr, bufnr, top, bottom) ---@type fml.dressing.indentline.IState
    local indents = state.indents ---@type table<integer, integer>

    vim.api.nvim_buf_call(bufnr, function()
      local parent_indent ---@type integer
      local current_indent ---@type integer
      for l = state.top, state.bottom do
        local indent = indents[l] ---@type integer|nil
        if not indent then
          local next = vim.fn.nextnonblank(l)
          -- Indent for a blank line is the minimum of the previous and next non-blank line.
          -- If the previous and next non-blank lines have different indents, add shiftwidth.
          if next ~= l then
            state.blanks[l] = true
            local prev = vim.fn.prevnonblank(l)
            indents[prev] = indents[prev] or vim.fn.indent(prev)
            indents[next] = indents[next] or vim.fn.indent(next)
            indent = math.min(indents[prev], indents[next])
            if indents[prev] ~= indents[next] then
              indent = indent + state.shiftwidth
            end
          else
            indent = vim.fn.indent(l)
          end
          indents[l] = indent
        end
        if indent ~= current_indent then
          parent_indent = current_indent or indent
          current_indent = indent
        end

        indent = math.min(indent, parent_indent + state.shiftwidth)
        if indent > 0 then
          local extmarks = get_extmarks(indent, state) ---@type vim.api.keyset.set_extmark[]
          for _, extmark in ipairs(extmarks) do
            vim.api.nvim_buf_set_extmark(bufnr, nsnr, l - 1, 0, extmark)
          end
        end
      end
    end)
  end,
})
