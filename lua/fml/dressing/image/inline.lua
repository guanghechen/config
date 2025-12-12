local __module_name__ = "fml.dressing.image.inline" ---@type string

---@class fml.dressing.image.inline
---@field public bufnr                    integer
---@field public imgs                     table<integer, fml.dressing.image.Placement>
---@field public idx                      table<integer, fml.dressing.image.Placement>
local M = {}
M.__index = M

---@param bufnr                           integer
---@return fml.dressing.image.inline
function M.new(bufnr)
  local self = setmetatable({}, M)
  self.bufnr = bufnr
  self.imgs = {}
  self.idx = {}
  local group = vim.api.nvim_create_augroup(__module_name__ .. "." .. bufnr, { clear = true })

  local debounced = ark.timer.debounce(function()
    self:update()
  end, 100)

  local function update()
    debounced()
  end

  vim.api.nvim_create_autocmd({ "BufWritePost", "WinScrolled", "BufWinEnter" }, {
    group = group,
    buffer = bufnr,
    callback = vim.schedule_wrap(update),
  })
  vim.api.nvim_create_autocmd({ "ModeChanged", "CursorMoved" }, {
    group = group,
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

---@return table<integer, fml.dressing.image.Placement>
function M:visible()
  local ret = {} ---@type table<integer, fml.dressing.image.Placement>
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
---@return table<integer, fml.dressing.image.Placement>
function M:get(from, to)
  local placement = require("fml.dressing.image.placement")
  local ret = {} ---@type table<integer, fml.dressing.image.Placement>
  local marks = vim.api.nvim_buf_get_extmarks(self.bufnr, placement.ns, { from - 1, 0 }, { to, -1 }, {
    overlap = true,
    hl_name = false,
  })
  for _, m in ipairs(marks) do
    local p = self.idx[m[1]] ---@type fml.dressing.image.Placement|nil
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
  local s = require("fml.dressing.image.state").data
  local doc = require("fml.dressing.image.doc")
  local placement = require("fml.dressing.image.placement")

  local conceal = s.doc.conceal
  conceal = type(conceal) ~= "function" and function()
    return conceal
  end or conceal

  doc.find_visible(self.bufnr, function(imgs)
    local visible = self:visible()
    for _, i in ipairs(imgs) do
      local img ---@type fml.dressing.image.Placement|nil
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
            conceal = vim.b[self.bufnr].fml_image_conceal or conceal(i.lang, i.type),
            type = i.type,
            ---@param p fml.dressing.image.Placement
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

return M
