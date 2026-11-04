---@diagnostic disable-next-line: unused-local
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
---@field protected _spinner            ?uv.uv_timer_t
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
local next_placement_id = 10

---Ids of closed placements, handed out again: each id names a highlight group (see `render_grid`), and Neovim never
---frees one and allows about 20000 in all.
---@type integer[]
local free_ids = {}

---@type boolean
local watching_windows = false

---Placements to draw again once a window shows them (see `redraw`).
---@type table<era.m.image.Placement, boolean>
local stale = setmetatable({}, { __mode = "k" })

---Updates the placements of the buffers the current tab shows that follow window sizes (viewers) or wait to be drawn
---again (see `redraw`).
---@return nil
local function update_shown()
  local seen = {} ---@type table<integer, boolean>
  for _, winnr in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    if not seen[bufnr] then
      seen[bufnr] = true
      for _, placement in pairs(placements[bufnr] or {}) do
        if placement.opts.auto_resize or stale[placement] then
          vim.schedule(function()
            placement:update()
          end)
        end
      end
    end
  end
end

---One listener serves every placement and visits only the buffers the current tab shows, so a window event costs the
---same however many images were opened.
---@return nil
local function watch_windows()
  if watching_windows then
    return
  end
  watching_windows = true
  vim.api.nvim_create_autocmd({ "WinClosed", "WinNew", "WinEnter", "WinResized" }, {
    group = vim.api.nvim_create_augroup(__module_name__ .. ".windows", { clear = true }),
    callback = function()
      update_shown()
    end,
  })
end

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

---Draws every placement again, as the terminal may have lost the images: the ones this tab shows at once, the others
---when a window shows them.
---@return nil
function M.redraw()
  for _, buffer_placements in pairs(placements) do
    for _, placement in pairs(buffer_placements) do
      placement._state = nil
      stale[placement] = true
    end
  end
  update_shown()
end

---@param bufnr                          integer
---@param src                            string
---@param opts                           ?era.m.image.Opts
---@return era.m.image.Placement
function M.new(bufnr, src, opts)
  local Image = require("era.m.image.image")
  assert(type(bufnr) == "number", "`Placement.new`: bufnr should be a number")
  assert(type(src) == "string", "`Placement.new`: src should be a string")
  local self = setmetatable({}, M)

  local id = table.remove(free_ids) ---@type integer|nil
  if id == nil then
    next_placement_id = next_placement_id + 1
    id = next_placement_id
  end
  self.id = id
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
      buf = self.bufnr,
      callback = function()
        vim.schedule(function()
          self:update()
        end)
      end,
    })
  end
  watch_windows()
  placements[self.bufnr] = placements[self.bufnr] or {}
  placements[self.bufnr][self.id] = self

  if self:ready() then
    vim.schedule(function()
      self:update()
    end)
  elseif self.opts.inline then
    -- A failed image is anchored as well, so the document finds this placement again instead of adding one.
    self:__render__({
      {
        row = self.opts.pos[1] - 1,
        col = self.opts.pos[2],
      },
    })
  elseif self.img:failed() then
    self:error()
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
  vim.api.nvim_set_option_value("modifiable", true, { buf = self.bufnr })
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = self.bufnr })
  vim.api.nvim_set_option_value("modified", false, { buf = self.bufnr })
  if not pcall(vim.treesitter.start, self.bufnr, "markdown") then
    vim.api.nvim_set_option_value("syntax", "markdown", { buf = self.bufnr })
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
  -- Nothing draws through the id any more: a closed placement never updates (see `ready`).
  free_ids[#free_ids + 1] = self.id
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
  -- A window column: the text before the image may hold wide characters or tabs.
  local offset = vim.fn.strdisplaywidth(lines[1]:sub(1, range[2])) ---@type integer
  local has_after = lines[#lines]:sub(range[4] + 1):find("%S") ~= nil
  local has_before = lines[1]:sub(1, range[2]):find("%S") ~= nil
  local conceal = self.opts.conceal and "" or nil
  local extmarks = {} ---@type era.m.image.Extmark[]

  local can_overlay = (#lines > 1 or not has_after)
  for _, winnr in ipairs(can_overlay and self:wins() or {}) do
    if vim.api.nvim_get_option_value("wrap", { win = winnr }) then
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
        invalidate = true,
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
      if last and #img == 0 and (last.row < range[3] - 1) then
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
      for _, l in ipairs(img) do
        table.insert(virt_lines, { { padding }, { l, hl } })
      end
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
    for _, l in ipairs(img) do
      table.insert(virt_lines, { { l, hl } })
    end
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

---@return era.m.image.State
function M:state()
  local state = require("era.m.image.state")
  local width, height = vim.o.columns, vim.o.lines
  local wins = self:wins()

  for _, winnr in ipairs(wins) do
    local info = vim.fn.getwininfo(winnr)[1]
    -- The image fits the text area, right of the line numbers and signs.
    width = math.min(width, info.width - info.textoff)
    height = math.min(height, info.height)
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
  self:__refresh__()
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

  -- Nothing is drawn without a window; a window showing the buffer again changes the state.
  if #cur_state.wins == 0 then
    return
  end
  self.img:place(self)

  if not self.opts.inline then
    for _, winnr in ipairs(cur_state.wins) do
      for k, v in pairs(s.wo or {}) do
        vim.api.nvim_set_option_value(k, v, { win = winnr, scope = "local" })
      end
    end
  end

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
  stale[self] = nil

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
  if self.opts.inline then
    return
  end
  vim.api.nvim_set_option_value("modifiable", true, { buf = self.bufnr })
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, {})
  vim.api.nvim_set_option_value("modifiable", false, { buf = self.bufnr })
  vim.api.nvim_set_option_value("modified", false, { buf = self.bufnr })
  -- A running spinner reads `self.img`, so it also covers an image this placement has switched to.
  if self:ready() or (self._spinner and not self._spinner:is_closing()) then
    return
  end
  local timer = assert(uv.new_timer())
  local eid = nil ---@type integer|nil
  self._spinner = timer
  timer:start(
    0,
    80,
    vim.schedule_wrap(function()
      if timer:is_closing() then
        return
      end
      local valid = vim.api.nvim_buf_is_valid(self.bufnr)
      if self.closed or not valid or self:ready() or self.img:failed() then
        stl.timer.clear_timer(timer)
        if eid ~= nil and valid then
          vim.api.nvim_buf_del_extmark(self.bufnr, ns, eid)
        end
        return
      end
      local current = self.img.convert and self.img.convert:current()
      local name = current and current.name or "image"
      eid = vim.api.nvim_buf_set_extmark(self.bufnr, ns, 0, 0, {
        id = eid,
        virt_text = {
          { "◐ ", "m_img_spinner" },
          { " " },
          { name .. " loading …", "m_img_loading" },
        },
      })
    end)
  )
end

---Follows the source to its current version, so a rewritten or newly created file is converted and shown.
---@return nil
function M:__refresh__()
  -- `bufnr` is unset while `new` registers this placement, which can already trigger an update.
  if self.closed or self.bufnr == nil or not vim.api.nvim_buf_is_valid(self.bufnr) then
    return
  end
  local img = self.img:latest()
  if img == self.img then
    return
  end
  self.img:del(self.id)
  self.img = img
  self._state = nil
  img:place(self)
  -- Clears a failure message the previous version left in a viewer and shows progress until it is ready.
  self:__progress__()
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
