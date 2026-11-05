---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.image.inline" ---@type string

---@class era.m.image.inline.IDocument
---@field public find_visible            fun(bufnr: integer, cb: era.m.image.find): nil
---@field public math_enabled            fun(bufnr: integer): boolean

---@class era.m.image.inline
---@field public bufnr                    integer
---@field public imgs                     table<integer, era.m.image.Placement>
---@field public idx                      table<integer, era.m.image.Placement>
---@field public disposed               ?boolean
---@field protected __call_debounced__    fun(self: era.m.image.inline): nil
---@field protected _debounced            ?stl.timer.IDisposableCallable
---@field protected _document             era.m.image.inline.IDocument
---@field protected _augroup              integer
---@field protected _flag_unsub           ?stl.c.IUnsubscribable
---@field protected _held                 ?boolean
local M = {}
M.__index = M

---@param bufnr                           integer
---@param document                       era.m.image.inline.IDocument
---@return era.m.image.inline
function M.new(bufnr, document)
  assert(type(document) == "table", "`Inline.new`: document should be a table")
  assert(type(document.find_visible) == "function", "`Inline.new`: document.find_visible should be a function")
  assert(type(document.math_enabled) == "function", "`Inline.new`: document.math_enabled should be a function")
  local self = setmetatable({}, M)
  self.bufnr = bufnr
  self.imgs = {}
  self.idx = {}
  self._document = document
  self._augroup = vim.api.nvim_create_augroup(__module_name__ .. "." .. bufnr, { clear = true })

  self._debounced = stl.timer.debounce(function()
    self:update()
  end, 100)

  local function update()
    self:__call_debounced__() ---@diagnostic disable-line: invisible
  end

  vim.api.nvim_create_autocmd({ "BufWritePost", "WinScrolled", "BufWinEnter" }, {
    group = self._augroup,
    buf = bufnr,
    callback = vim.schedule_wrap(update),
  })
  vim.api.nvim_create_autocmd({ "ModeChanged", "CursorMoved" }, {
    group = self._augroup,
    buf = bufnr,
    callback = function(ev)
      if ev.buf == self.bufnr and ev.buf == vim.api.nvim_get_current_buf() then
        self:conceal()
      end
    end,
  })
  vim.api.nvim_buf_attach(bufnr, false, {
    on_lines = function()
      if self.disposed then
        return true
      end
      update()
    end,
    -- `checktime` keeps the attachment across a reload but replaces the text before reading the file, so the
    -- placements are rebuilt once the new text is in.
    on_reload = function()
      vim.schedule(function()
        self:__reload__()
      end)
    end,
    -- Unloading the buffer (`:edit`, `:bdelete`) ends the attachment; `doc` attaches anew once it is read again.
    on_detach = function()
      self:dispose()
    end,
  })

  -- Images follow the `dressing_image` flight, and inline math also mirrors render-markdown's rendering state (see
  -- doc.math_enabled): re-sync on the flight, the global `render_markdown` flag, and the per-buffer `<leader>um`
  -- toggle (which fires the `User EraImageMathSync` event below since it has no observable).
  self._flag_unsub = stl.fn.observe({
    dot.context.flight.dressing_image,
    dot.context.plugin.render_markdown,
  }, function()
    self:sync()
  end, true)
  vim.api.nvim_create_autocmd("User", {
    pattern = "EraImageMathSync",
    group = self._augroup,
    callback = function(ev)
      if not (ev.data and ev.data.buf) or ev.data.buf == self.bufnr then
        self:sync()
      end
    end,
  })

  vim.schedule(update)
  return self
end

---@return nil
function M:dispose()
  if self.disposed then
    return
  end
  self.disposed = true
  if self._debounced then
    self._debounced:dispose()
    self._debounced = nil
  end
  if self._flag_unsub then
    self._flag_unsub:unsubscribe()
    self._flag_unsub = nil
  end
  pcall(vim.api.nvim_del_augroup_by_id, self._augroup)
  for _, img in pairs(self.imgs) do
    img:close()
  end
  self.imgs = {}
  self.idx = {}
end

---Closes what the switches no longer show: every image with the `dressing_image` flight off, and the formulas when
---math is not rendered; `update` shows the rest again.
---@return nil
function M:sync()
  local shown = dot.context.flight.dressing_image:snapshot() ---@type boolean
  local math = shown and self._document.math_enabled(self.bufnr)
  for id, img in pairs(self.imgs) do
    if not shown or (img.opts.type == "math" and not math) then
      img:close()
      self.imgs[id] = nil
    end
  end
  self:update()
end

---@return nil
function M:conceal()
  -- Typing has ended or left the line: draw what `update` held back there.
  if self._held and self:__typing_row__() == nil then
    self._held = false
    self:__call_debounced__()
  end
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local mode = vim.fn.mode():sub(1, 1):lower() ---@type string
  for _, img in pairs(self.imgs) do
    img:show()
  end
  if vim.api.nvim_get_option_value("concealcursor", { win = winnr }):find(mode) then
    return
  end
  local from, to = vim.fn.line("v"), vim.fn.line(".")
  from, to = math.min(from, to), math.max(from, to)
  local hide = self:get(from, to)
  for _, img in pairs(hide) do
    if img.opts.conceal then
      img:hide()
    end
  end
end

---@return table<integer, era.m.image.Placement>
function M:visible()
  local ret = {} ---@type table<integer, era.m.image.Placement>
  for _, winnr in ipairs(vim.fn.win_findbuf(self.bufnr)) do
    local info = vim.fn.getwininfo(winnr)[1]
    -- The lines `doc.find_visible` searches: `botline` is the last line shown whole, the next one may show in part.
    for k, v in pairs(self:get(math.max(info.topline - 1, 1), info.botline + 1)) do
      ret[k] = v
    end
  end
  return ret
end

---The placements with a mark on the lines `from` to `to` (1-based, both included).
---@param from                           integer
---@param to                             integer
---@return table<integer, era.m.image.Placement>
function M:get(from, to)
  local placement = require("era.m.image.placement")
  local ret = {} ---@type table<integer, era.m.image.Placement>
  local marks = vim.api.nvim_buf_get_extmarks(self.bufnr, placement.ns, { from - 1, 0 }, { to - 1, -1 }, {
    overlap = true,
    hl_name = false,
  })
  for _, m in ipairs(marks) do
    local p = self.idx[m[1]] ---@type era.m.image.Placement|nil
    -- A closed placement may have passed its id on to a new one.
    if p and self.imgs[p.id] ~= p then
      self.idx[m[1]] = nil
      p = nil
    end
    if p then
      ret[p.id] = p
    end
  end
  return ret
end

---@return nil
function M:update()
  if self.disposed or not dot.context.flight.dressing_image:snapshot() then
    return
  end
  local s = require("era.m.image.state").data
  local placement = require("era.m.image.placement")

  local conceal = s.doc.conceal
  conceal = type(conceal) ~= "function" and function()
    return conceal
  end or conceal

  self._document.find_visible(self.bufnr, function(imgs)
    local visible = self:visible()
    local typing = self:__typing_row__() ---@type integer|nil
    self._held = false
    for _, i in ipairs(imgs) do
      local img ---@type era.m.image.Placement|nil
      for v, o in pairs(visible) do
        if o.img.src == i.src then
          img = o
          visible[v] = nil
          break
        end
      end
      local concealed = vim.b[self.bufnr][dot.var.N_IMAGE_CONCEAL] or conceal(i.lang, i.type) ---@type boolean
      if img then
        img.opts.pos = i.pos
        img.opts.range = i.range
        img:update()
      elseif concealed and typing ~= nil and i.range[1] <= typing and typing <= i.range[3] then
        -- The line being typed shows its source (see `conceal`): a formula there waits until typing ends, instead of
        -- converting every state it passes through.
        self._held = true
      else
        img = placement.new(
          self.bufnr,
          i.src,
          vim.tbl_deep_extend("force", {}, s.doc, {
            pos = i.pos,
            range = i.range,
            inline = true,
            conceal = concealed,
            type = i.type,
            ---@param p era.m.image.Placement
            on_update = function(p)
              for _, eid in ipairs(p.eids) do
                self.idx[eid] = p
              end
            end,
          })
        )
        for _, eid in ipairs(img.eids) do
          self.idx[eid] = img
        end
        self.imgs[img.id] = img
      end
    end
    for _, img in pairs(visible) do
      img:close()
      self.imgs[img.id] = nil
    end
  end)
end

---The line typed on in this buffer's window when `conceal` shows it as source: Insert or Replace mode without
---`concealcursor` for it.
---@protected
---@return integer|nil
function M:__typing_row__()
  if vim.api.nvim_get_current_buf() ~= self.bufnr then
    return nil
  end
  local mode = vim.fn.mode():sub(1, 1):lower() ---@type string
  local concealcursor = vim.api.nvim_get_option_value("concealcursor", { win = 0 }) ---@type string
  if (mode ~= "i" and mode ~= "r") or concealcursor:find(mode, 1, true) then
    return nil
  end
  return vim.api.nvim_win_get_cursor(0)[1]
end

----------------------------------------------------------------------------------------------------

---@protected
---@return nil
function M:__call_debounced__()
  if self._debounced then
    self._debounced()
  end
end

---The reloaded text says nothing about where the old images were, so every placement is rebuilt.
---@return nil
function M:__reload__()
  if self.disposed then
    return
  end
  for _, img in pairs(self.imgs) do
    img:close()
  end
  self.imgs = {}
  self.idx = {}
  self:update()
end

return M
