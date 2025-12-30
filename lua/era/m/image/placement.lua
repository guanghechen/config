local __module_name__ = "era.m.image.placement" ---@type string

---@alias era.m.image.Extmark      vim.api.keyset.set_extmark|{row: integer, col: integer}

---@class era.m.image.Opts
---@field public pos                      ?era.m.image.Pos
---@field public range                    ?integer[]
---@field public conceal                  ?boolean
---@field public inline                   ?boolean
---@field public width                    ?integer
---@field public min_width                ?integer
---@field public max_width                ?integer
---@field public height                   ?integer
---@field public min_height               ?integer
---@field public max_height               ?integer
---@field public on_update                ?fun(placement: era.m.image.Placement)
---@field public on_update_pre            ?fun(placement: era.m.image.Placement)
---@field public type                     ?era.m.image.Type
---@field public auto_resize              ?boolean

---@class era.m.image.State
---@field public hidden                   boolean
---@field public loc                      era.m.image.Loc
---@field public wins                     integer[]

---@class era.m.image.Placement
---@field public img                      era.m.image.Image
---@field public id                       integer
---@field public ns                       integer
---@field public bufnr                    integer
---@field public opts                     era.m.image.Opts
---@field public augroup                  integer
---@field public hidden                   ?boolean
---@field public closed                   ?boolean
---@field public type                     ?era.m.image.Type
---@field public eids                     integer[]
---@field public update                   fun(self: era.m.image.Placement): nil
---@field protected _loc                  ?era.m.image.Loc
---@field protected _state                ?era.m.image.State
---@field protected _extmarks             ?era.m.image.Extmark[]
---@field protected _debounced            ?stl.timer.IDisposableCallable
local M = {}
M.__index = M

local uv = vim.uv
local ns = vim.api.nvim_create_namespace(__module_name__)
local PLACEHOLDER = vim.fn.nr2char(0x10EEEE)

---@type table<integer, table<integer, era.m.image.Placement>>
local placements = {}

-- stylua: ignore
local diacritics = vim.split("0305,030D,030E,0310,0312,033D,033E,033F,0346,034A,034B,034C,0350,0351,0352,0357,035B,0363,0364,0365,0366,0367,0368,0369,036A,036B,036C,036D,036E,036F,0483,0484,0485,0486,0487,0592,0593,0594,0595,0597,0598,0599,059C,059D,059E,059F,05A0,05A1,05A8,05A9,05AB,05AC,05AF,05C4,0610,0611,0612,0613,0614,0615,0616,0617,0657,0658,0659,065A,065B,065D,065E,06D6,06D7,06D8,06D9,06DA,06DB,06DC,06DF,06E0,06E1,06E2,06E4,06E7,06E8,06EB,06EC,0730,0732,0733,0735,0736,073A,073D,073F,0740,0741,0743,0745,0747,0749,074A,07EB,07EC,07ED,07EE,07EF,07F0,07F1,07F3,0816,0817,0818,0819,081B,081C,081D,081E,081F,0820,0821,0822,0823,0825,0826,0827,0829,082A,082B,082C,082D,0951,0953,0954,0F82,0F83,0F86,0F87,135D,135E,135F,17DD,193A,1A17,1A75,1A76,1A77,1A78,1A79,1A7A,1A7B,1A7C,1B6B,1B6D,1B6E,1B6F,1B70,1B71,1B72,1B73,1CD0,1CD1,1CD2,1CDA,1CDB,1CE0,1DC0,1DC1,1DC3,1DC4,1DC5,1DC6,1DC7,1DC8,1DC9,1DCB,1DCC,1DD1,1DD2,1DD3,1DD4,1DD5,1DD6,1DD7,1DD8,1DD9,1DDA,1DDB,1DDC,1DDD,1DDE,1DDF,1DE0,1DE1,1DE2,1DE3,1DE4,1DE5,1DE6,1DFE,20D0,20D1,20D4,20D5,20D6,20D7,20DB,20DC,20E1,20E7,20E9,20F0,2CEF,2CF0,2CF1,2DE0,2DE1,2DE2,2DE3,2DE4,2DE5,2DE6,2DE7,2DE8,2DE9,2DEA,2DEB,2DEC,2DED,2DEE,2DEF,2DF0,2DF1,2DF2,2DF3,2DF4,2DF5,2DF6,2DF7,2DF8,2DF9,2DFA,2DFB,2DFC,2DFD,2DFE,2DFF,A66F,A67C,A67D,A6F0,A6F1,A8E0,A8E1,A8E2,A8E3,A8E4,A8E5,A8E6,A8E7,A8E8,A8E9,A8EA,A8EB,A8EC,A8ED,A8EE,A8EF,A8F0,A8F1,AAB0,AAB2,AAB3,AAB7,AAB8,AABE,AABF,AAC1,FE20,FE21,FE22,FE23,FE24,FE25,FE26,10A0F,10A38,1D185,1D186,1D187,1D188,1D189,1D1AA,1D1AB,1D1AC,1D1AD,1D242,1D243,1D244", ",")

---@type table<integer, string>
local positions = {}
setmetatable(positions, {
  __index = function(_, k)
    positions[k] = vim.fn.nr2char(tonumber(diacritics[k], 16))
    return positions[k]
  end,
})

---@type integer
M._pid = 10

M.ns = ns

---@param bufnr                          ?integer
---@param id                             ?integer
---@return nil
function M.clean(bufnr, id)
  for _, b in ipairs(bufnr and { bufnr } or vim.tbl_keys(placements)) do
    for _, p in ipairs(id and { placements[b][id] } or vim.tbl_values(placements[b] or {})) do
      if p then
        p:close()
      end
    end
  end
end

---@param bufnr                          integer
---@param src                            string
---@param opts                           ?era.m.image.Opts
---@return era.m.image.Placement
function M.new(bufnr, src, opts)
  local Image = require("era.m.image.image")
  assert(type(bufnr) == "number", "`Image.new`: bufnr should be a number")
  assert(type(src) == "string", "`Image.new`: src should be a string")
  local self = setmetatable({}, M)

  self.img = Image.new(src)
  self.img:place(self)
  self.opts = opts or {}
  self.opts.pos = self.opts.pos or { 1, 0 }
  self.bufnr = bufnr
  self.augroup = vim.api.nvim_create_augroup(__module_name__ .. "." .. self.id, { clear = true })
  self.eids = {}

  if self.opts.auto_resize then
    vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter", "BufWinLeave", "BufEnter" }, {
      group = self.augroup,
      buffer = self.bufnr,
      callback = function()
        vim.schedule(function()
          self:update()
        end)
      end,
    })
    vim.api.nvim_create_autocmd({ "WinClosed", "WinNew", "WinEnter", "WinResized" }, {
      group = self.augroup,
      callback = function()
        vim.schedule(function()
          self:update()
        end)
      end,
    })
  end
  placements[self.bufnr] = placements[self.bufnr] or {}
  placements[self.bufnr][self.id] = self

  if self:ready() then
    vim.schedule(function()
      self:update()
    end)
  elseif self.img:failed() then
    self:error()
  elseif self.opts.inline then
    self:__render__({
      {
        row = self.opts.pos[1] - 1,
        col = self.opts.pos[2],
      },
    })
  else
    self:__progress__()
  end

  local update_fn = self.update
  local debounced = stl.timer.debounce(function()
    update_fn(self)
  end, 10)
  self._debounced = debounced
  self.update = function(_)
    debounced()
  end
  return self
end

---@return nil
function M:error()
  if self.opts.inline then
    return
  end
  local msg = "# Image Conversion Failed:\n\n"
  local convert = self.img.convert
  if convert then
    for _, step in ipairs(convert.steps) do
      if step.err then
        msg = msg .. "## " .. step.name .. "\n\n" .. step.err .. "\n\n"
        if step.proc then
          msg = msg .. "# Output\n" .. vim.trim(step.proc:out() .. "\n" .. step.proc:err()) .. "\n"
        end
      end
    end
  end
  local lines = vim.split(msg, "\n")
  vim.bo[self.bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, lines)
  vim.bo[self.bufnr].modifiable = false
  if not vim.treesitter.start(self.bufnr, "markdown") then
    vim.bo[self.bufnr].syntax = "markdown"
  end
end

---@return integer[]
function M:wins()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  ---@param winnr integer
  return vim.tbl_filter(function(winnr)
    return vim.api.nvim_win_get_buf(winnr) == self.bufnr
  end, vim.api.nvim_tabpage_list_wins(tabnr))
end

---@return nil
function M:close()
  if self.closed then
    return
  end
  placements[self.bufnr][self.id] = nil
  self.closed = true
  if self._debounced then
    self._debounced:dispose()
    self._debounced = nil
  end
  self:del()
  pcall(vim.api.nvim_del_augroup_by_id, self.augroup)
end

---@return nil
function M:del()
  self.img:del(self.id)
  if vim.api.nvim_buf_is_valid(self.bufnr) then
    for _, eid in ipairs(self.eids) do
      vim.api.nvim_buf_del_extmark(self.bufnr, ns, eid)
    end
  end
end

---@param row                            integer
---@param col                            integer
---@return boolean
function M:is_concealed(row, col)
  local captures = vim.treesitter.get_captures_at_pos(self.bufnr, row, col)
  for _, cap in ipairs(captures) do
    if vim.tbl_get(cap, "metadata", "conceal_lines") ~= nil then
      return true
    end
  end
  return false
end

---@param row                            integer
---@return integer
function M:find_line(row)
  local line_count = vim.api.nvim_buf_line_count(self.bufnr)
  while row < line_count and self:is_concealed(row, 0) do
    row = row + 1
  end
  return row
end

---@param loc                            era.m.image.Loc
---@return nil
function M:render_grid(loc)
  local s = require("era.m.image.state").data
  local hl = "m_img_" .. self.id
  vim.api.nvim_set_hl(0, hl, {
    fg = self.img.id,
    sp = self.id,
    bg = "none",
    nocombine = true,
  })
  local img = {} ---@type string[]
  local height = math.min(#diacritics, loc.height)
  local width = math.min(#diacritics, loc.width)

  local border_hl = "m_img_border"
  local border_chars = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }
  local top_border = border_chars[1] .. string.rep(border_chars[2], width) .. border_chars[3]
  local bottom_border = border_chars[7] .. string.rep(border_chars[6], width) .. border_chars[5]

  for r = 1, height do
    local line = {} ---@type string[]
    for c = 1, width do
      line[#line + 1] = PLACEHOLDER
      line[#line + 1] = positions[r]
      line[#line + 1] = positions[c]
    end
    img[#img + 1] = table.concat(line)
  end

  local range = self.opts.range or { loc[1], loc[2], loc[1], loc[2] }
  local lines = vim.api.nvim_buf_get_lines(self.bufnr, range[1] - 1, range[3], false)
  local text_width = 0
  for _, line in ipairs(lines) do
    text_width = math.max(text_width, vim.api.nvim_strwidth(line))
  end
  local offset = range[2]
  local has_after = lines[#lines]:sub(range[4] + 1):find("%S") ~= nil
  local has_before = lines[1]:sub(1, range[2]):find("%S") ~= nil
  local conceal = self.opts.conceal and "" or nil
  local extmarks = {} ---@type era.m.image.Extmark[]

  local can_overlay = (#lines > 1 or not has_after)
  for _, winnr in ipairs(can_overlay and self:wins() or {}) do
    if vim.wo[winnr].wrap then
      local info = vim.fn.getwininfo(winnr)[1]
      if info.width - info.textoff < text_width then
        can_overlay = false
        break
      end
    end
  end

  if height == 1 and #lines == 1 then
    self:__render__({
      {
        row = range[1] - 1,
        col = range[2],
        end_row = range[3] - 1,
        end_col = range[4],
        conceal = conceal,
        invalidate = vim.fn.has("nvim-0.10") == 1 and true or nil,
        virt_text_pos = "inline",
        virt_text = { { img[1], hl } },
        virt_text_hide = true,
      },
    })
  elseif can_overlay then
    if conceal then
      if not self:is_concealed(range[1] - 1, range[2]) then
        extmarks[#extmarks + 1] = {
          row = range[1] - 1,
          col = range[2],
          end_row = range[3] - 1,
          end_col = range[4],
          conceal = conceal,
          virt_text_pos = "overlay",
          virt_text = { { table.remove(img, 1), hl } },
          virt_text_hide = false,
          virt_text_win_col = offset,
        }
      end
      for i = 1, math.min(#img, #lines - 1) do
        if self:is_concealed(range[1] - 1 + i, 0) then
          break
        end
        extmarks[#extmarks + 1] = {
          row = range[1] - 1 + i,
          col = 0,
          virt_text_pos = "overlay",
          virt_text = { { table.remove(img, 1), hl } },
          virt_text_hide = false,
          virt_text_win_col = offset,
        }
      end
      local last = extmarks[#extmarks]
      if last and #img == 0 and (last.row < range[3] - 1) and vim.fn.has("nvim-0.11.4") == 1 then
        extmarks[#extmarks + 1] = {
          row = last.row + 1,
          end_row = range[3] - 1,
          col = 0,
          conceal_lines = "",
          virt_text_hide = false,
        }
      end
    end
    if #img > 0 then
      local row = self:find_line(range[3] - 1)
      local padding = string.rep(" ", offset)
      local virt_lines = {} ---@type {[1]: string, [2]: string}[][]
      table.insert(virt_lines, { { padding }, { top_border, border_hl } })
      for _, l in ipairs(img) do
        table.insert(
          virt_lines,
          { { padding }, { border_chars[8], border_hl }, { l, hl }, { border_chars[4], border_hl } }
        )
      end
      table.insert(virt_lines, { { padding }, { bottom_border, border_hl } })
      extmarks[#extmarks + 1] = {
        row = row,
        col = 0,
        virt_lines_above = row ~= range[3] - 1,
        virt_lines = virt_lines,
        virt_text_hide = false,
      }
    end
    self:__render__(extmarks)
  else
    local is_inline = has_before or has_after
    local icons = s.icons
    local icon = icons[self.opts.type or "image"] or icons.image
    local virt_lines = {} ---@type {[1]: string, [2]: string}[][]
    table.insert(virt_lines, { { top_border, border_hl } })
    for _, l in ipairs(img) do
      table.insert(virt_lines, { { border_chars[8], border_hl }, { l, hl }, { border_chars[4], border_hl } })
    end
    table.insert(virt_lines, { { bottom_border, border_hl } })
    extmarks[#extmarks + 1] = {
      row = range[1] - 1,
      col = range[2],
      end_row = range[3] - 1,
      end_col = range[4],
      conceal = conceal,
      virt_text = is_inline and { { icon, "m_img_anchor" } } or nil,
      virt_text_pos = "inline",
      virt_text_hide = false,
      virt_lines = virt_lines,
    }
    self:__render__(extmarks)
  end
end

---@param state                          era.m.image.State
---@return nil
function M:render_fallback(state)
  local terminal = require("era.m.image.terminal")
  if not self.opts.inline then
    vim.api.nvim_buf_clear_namespace(self.bufnr, ns, 0, -1)
  end
  for _, winnr in ipairs(state.wins) do
    local win_config = vim.api.nvim_win_get_config(winnr)
    local border_top = 0
    local border_left = 0
    if win_config.border then
      border_top = 1
      border_left = 1
    end
    local pos = vim.api.nvim_win_get_position(winnr)
    if (vim.o.showtabline == 2) or (vim.o.showtabline == 1 and vim.fn.tabpagenr("$") > 1) then
      terminal.set_cursor({ pos[1] + border_top, pos[2] + border_left })
    else
      terminal.set_cursor({ pos[1] + 1 + border_top, pos[2] + border_left })
    end
    terminal.request({
      a = "p",
      i = self.img.id,
      p = self.id,
      C = 1,
      c = state.loc.width,
      r = state.loc.height,
    })
  end
end

---@return era.m.image.State
function M:state()
  local state = require("era.m.image.state")
  local width, height = vim.o.columns, vim.o.lines
  local wins = {} ---@type integer[]
  local is_fallback = not state.env.placeholders
  local zindex = vim.api.nvim_win_get_config(0).zindex or 0

  for _, winnr in ipairs(self:wins()) do
    width = math.min(width, vim.api.nvim_win_get_width(winnr))
    height = math.min(height, vim.api.nvim_win_get_height(winnr))
    if is_fallback then
      local z = vim.api.nvim_win_get_config(winnr).zindex or 0
      if z >= zindex or (zindex > 0 and z > 0) then
        wins[#wins + 1] = winnr
      end
    else
      wins[#wins + 1] = winnr
    end
  end

  local function minmax(value, min, max)
    return math.max(min or 1, math.min(value, max or value))
  end

  width = minmax(self.opts.width or width, self.opts.min_width, self.opts.max_width)
  height = minmax(self.opts.height or height, self.opts.min_height, self.opts.max_height)
  local size = state.fit(self.img.file, { width = width, height = height }, { info = self.img.info })

  local pos = self.opts.pos or { 1, 0 }

  local function is_inline()
    local range = self.opts.range or { pos[1], pos[2], pos[1], pos[2] }
    if range[1] == range[3] then
      local line = vim.api.nvim_buf_get_lines(self.bufnr, range[1] - 1, range[1], false)[1] or ""
      local has_before = line:sub(1, range[2]):find("%S") ~= nil
      local has_after = line:sub(range[4] + 1):find("%S") ~= nil
      return has_before or has_after
    end
  end

  if size.height <= 2 and is_inline() then
    size.width = math.ceil(size.width / size.height) + 2
    size.height = 1
  end

  ---@type era.m.image.State
  return {
    hidden = self.hidden or false,
    loc = {
      pos[1],
      pos[2],
      width = size.width,
      height = size.height,
    },
    wins = wins,
  }
end

---@return boolean
function M:valid()
  return self.bufnr
    and vim.api.nvim_buf_is_valid(self.bufnr)
    and self:ready()
    and self.opts.pos[1] <= vim.api.nvim_buf_line_count(self.bufnr)
end

---@return nil
function M:update()
  local state = require("era.m.image.state")
  local s = state.data
  local terminal = require("era.m.image.terminal")
  if not self:ready() then
    return
  end

  if not self:valid() then
    self:del()
    return
  end

  if self.opts.on_update_pre then
    self.opts.on_update_pre(self)
  end

  local cur_state = self:state()
  if vim.deep_equal(cur_state, self._state) then
    return
  end
  self._state = cur_state

  if #cur_state.wins == 0 then
    self:hide()
    return
  end
  self.img:place(self)

  if not self.opts.inline then
    for _, winnr in ipairs(cur_state.wins) do
      for k, v in pairs(s.wo or {}) do
        vim.wo[winnr][k] = v
      end
    end
  end

  if state.env.placeholders then
    terminal.request({
      a = "p",
      U = 1,
      i = self.img.id,
      p = self.id,
      C = 1,
      c = cur_state.loc.width,
      r = cur_state.loc.height,
    })
    self:render_grid(cur_state.loc)
  else
    self:render_fallback(cur_state)
  end

  if not self.opts.inline then
    for _, winnr in ipairs(cur_state.wins) do
      vim.api.nvim_win_call(winnr, function()
        vim.fn.winrestview({ topline = 1, lnum = 1, col = 0, leftcol = 0 })
      end)
    end
  end
  if self.opts.on_update then
    self.opts.on_update(self)
  end
end

---@return boolean
function M:ready()
  return not self.closed and self.bufnr and vim.api.nvim_buf_is_valid(self.bufnr) and self.img:ready()
end

---@return nil
function M:hide()
  if self.hidden or not self:ready() then
    return
  end
  self.hidden = true
  self:update()
end

---@return nil
function M:show()
  if not self.hidden or not self:ready() then
    return
  end
  self.hidden = false
  self:update()
end

----------------------------------------------------------------------------------------------------

---@return nil
function M:__progress__()
  if self.opts.inline or self:ready() then
    return
  end
  vim.bo[self.bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, {})
  vim.bo[self.bufnr].modifiable = false
  local timer = assert(uv.new_timer())
  timer:start(
    0,
    80,
    vim.schedule_wrap(function()
      if self:ready() or self.img:failed() or not vim.api.nvim_buf_is_valid(self.bufnr) then
        stl.timer.clear_timer(timer)
        return
      end
      vim.api.nvim_buf_clear_namespace(self.bufnr, ns, 0, -1)
      local current = self.img.convert and self.img.convert:current()
      local name = current and current.name or "image"
      vim.api.nvim_buf_set_extmark(self.bufnr, ns, 0, 0, {
        virt_text = {
          { "◐ ", "m_img_spinner" },
          { " " },
          { name .. " loading …", "m_img_loading" },
        },
      })
    end)
  )
end

---@param extmarks                       era.m.image.Extmark[]
---@return nil
function M:__render__(extmarks)
  for _, e in ipairs(extmarks) do
    e.undo_restore = false
    e.strict = false
    if self.hidden then
      e.virt_text = nil
      e.conceal = nil
      if e.virt_lines then
        e.virt_lines = vim.tbl_map(function(_)
          return { { "" } }
        end, e.virt_lines)
      end
    end
  end
  local eids = {} ---@type integer[]
  for _, extmark in ipairs(extmarks) do
    local row, col = extmark.row, extmark.col
    extmark.row, extmark.col, extmark.id = nil, nil, table.remove(self.eids, 1)
    table.insert(eids, vim.api.nvim_buf_set_extmark(self.bufnr, ns, row, col, extmark))
  end
  for _, eid in ipairs(self.eids) do
    vim.api.nvim_buf_del_extmark(self.bufnr, ns, eid)
  end
  self.eids = eids
end

return M
