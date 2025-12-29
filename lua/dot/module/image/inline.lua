local __module_name__ = "dot.module.image.inline" ---@type string

---@class dot.module.image.inline
---@field public bufnr                    integer
---@field public imgs                     table<integer, dot.module.image.Placement>
---@field public idx                      table<integer, dot.module.image.Placement>
---@field protected __call_debounced__    fun(self: dot.module.image.inline): nil
---@field protected _debounced            ?stl.timer.IDisposableCallable
---@field protected _augroup              integer
local M = {}
M.__index = M

---@param bufnr                           integer
---@return dot.module.image.inline
function M.new(bufnr)
  local self = setmetatable({}, M)
  self.bufnr = bufnr
  self.imgs = {}
  self.idx = {}
  self._augroup = vim.api.nvim_create_augroup(__module_name__ .. "." .. bufnr, { clear = true })

  self._debounced = stl.timer.debounce(function()
    self:update()
  end, 100)

  local function update()
    self:__call_debounced__() ---@diagnostic disable-line: invisible
  end

  vim.api.nvim_create_autocmd({ "BufWritePost", "WinScrolled", "BufWinEnter" }, {
    group = self._augroup,
    buffer = bufnr,
    callback = vim.schedule_wrap(update),
  })
  vim.api.nvim_create_autocmd({ "ModeChanged", "CursorMoved" }, {
    group = self._augroup,
    buffer = bufnr,
    callback = function(ev)
      if ev.buf == self.bufnr and ev.buf == vim.api.nvim_get_current_buf() then
        self:conceal()
      end
    end,
  })
  vim.api.nvim_buf_attach(bufnr, false, {
    on_lines = function()
      update()
    end,
  })
  vim.schedule(update)
  return self
end

---@return nil
function M:dispose()
  if self._debounced then
    self._debounced:dispose()
    self._debounced = nil
  end
  pcall(vim.api.nvim_del_augroup_by_id, self._augroup)
  for _, img in pairs(self.imgs) do
    img:close()
  end
  self.imgs = {}
  self.idx = {}
end

---@return nil
function M:conceal()
  local mode = vim.fn.mode():sub(1, 1):lower() ---@type string
  for _, img in pairs(self.imgs) do
    img:show()
  end
  if vim.wo.concealcursor:find(mode) then
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

---@return table<integer, dot.module.image.Placement>
function M:visible()
  local ret = {} ---@type table<integer, dot.module.image.Placement>
  for _, winnr in ipairs(vim.fn.win_findbuf(self.bufnr)) do
    local info = vim.fn.getwininfo(winnr)[1]
    for k, v in pairs(self:get(math.max(info.topline - 1, 1), info.botline)) do
      ret[k] = v
    end
  end
  return ret
end

---@param from                           integer
---@param to                             integer
---@return table<integer, dot.module.image.Placement>
function M:get(from, to)
  local placement = require("dot.module.image.placement")
  local ret = {} ---@type table<integer, dot.module.image.Placement>
  local marks = vim.api.nvim_buf_get_extmarks(self.bufnr, placement.ns, { from - 1, 0 }, { to, -1 }, {
    overlap = true,
    hl_name = false,
  })
  for _, m in ipairs(marks) do
    local p = self.idx[m[1]] ---@type dot.module.image.Placement|nil
    if p and not self.imgs[p.id] then
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
  local s = require("dot.module.image.state").data
  local doc = require("dot.module.image.doc")
  local placement = require("dot.module.image.placement")

  local conceal = s.doc.conceal
  conceal = type(conceal) ~= "function" and function()
    return conceal
  end or conceal

  doc.find_visible(self.bufnr, function(imgs)
    local visible = self:visible()
    for _, i in ipairs(imgs) do
      local img ---@type dot.module.image.Placement|nil
      for v, o in pairs(visible) do
        if o.img.src == i.src then
          img = o
          visible[v] = nil
          break
        end
      end
      if not img then
        img = placement.new(
          self.bufnr,
          i.src,
          vim.tbl_deep_extend("force", {}, s.doc, {
            pos = i.pos,
            range = i.range,
            inline = true,
            conceal = vim.b[self.bufnr][ark.var.N_IMAGE_CONCEAL] or conceal(i.lang, i.type),
            type = i.type,
            ---@param p dot.module.image.Placement
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
      else
        img.opts.pos = i.pos
        img.opts.range = i.range
        img:update()
      end
    end
    for _, img in pairs(visible) do
      img:close()
      self.imgs[img.id] = nil
    end
  end)
end

----------------------------------------------------------------------------------------------------

---@protected
---@return nil
function M:__call_debounced__()
  if self._debounced then
    self._debounced()
  end
end

return M
