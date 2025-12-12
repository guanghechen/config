local __module_name__ = "fml.dressing.image.doc" ---@type string

---@class fml.dressing.image.doc
local M = {}

---@alias TSMatch                        {node: TSNode, meta: vim.treesitter.query.TSMetadata}

---@alias fml.dressing.image.transform   fun(match: fml.dressing.image.match, ctx: fml.dressing.image.ctx)

---@alias fml.dressing.image.find        fun(matches: fml.dressing.image.match[])

---@alias LinkDefinition                 {label: string, dest: string}

---@class fml.dressing.image.Hover
---@field public img                     fml.dressing.image.Placement
---@field public winnr                   integer
---@field public bufnr                   integer

---@class fml.dressing.image.ctx
---@field public bufnr                   integer
---@field public lang                    string
---@field public meta                    vim.treesitter.query.TSMetadata
---@field public pos                     ?TSMatch
---@field public src                     ?TSMatch
---@field public content                 ?TSMatch
---@field public ref                     ?TSMatch
---@field public definition              ?LinkDefinition

---@class fml.dressing.image.match
---@field public id                      string
---@field public pos                     fml.dressing.image.Pos
---@field public src                     ?string
---@field public content                 ?string
---@field public content_id              ?string
---@field public ext                     ?string
---@field public range                   ?integer[]
---@field public lang                    string
---@field public type                    fml.dressing.image.Type

local META_EXT = "image.ext"
local META_SRC = "image.src"
local META_TYPE = "image.type"
local META_IGNORE = "image.ignore"
local META_LANG = "image.lang"

---@type table<string, fml.dressing.image.transform>
M.transforms = {
  norg = function(img, ctx)
    local row, col = ctx.src.node:start()
    local line = vim.api.nvim_buf_get_lines(ctx.bufnr, row, row + 1, false)[1]
    img.src = line:sub(col + 1)
  end,
  typst = function(img, ctx)
    if not img.content then
      return
    end
    local state = require("fml.dressing.image.state")
    local s = state.data
    local color_val = vim.api.nvim_get_hl(0, { name = "f_image_math" }).fg
    local color = color_val and string.format("#%06x", color_val) or "#000000"
    img.content = state.tpl(s.math.typst.tpl, {
      color = color,
      header = M.get_header(ctx.bufnr),
      content = img.content,
    })
  end,
  latex = function(img, ctx)
    local state = require("fml.dressing.image.state")
    local s = state.data
    if not (img.content and img.ext == "math.tex") then
      return
    end
    local color_val = vim.api.nvim_get_hl(0, { name = "f_image_math" }).fg
    local fg = color_val and string.format("#%06x", color_val) or "#000000"
    local content = vim.trim(img.content or "")
    content = content:gsub("^%$+`?", ""):gsub("`?%$+$", "")
    content = content:gsub("^\\[%[%(]", ""):gsub("\\[%]%)]$", "")
    if not content:find("^\\begin") then
      content = ("\\[%s\\]"):format(content)
    end
    local packages = { "xcolor" }
    vim.list_extend(packages, s.math.latex.packages)
    vim.list_extend(packages, M.get_packages(ctx.bufnr))
    table.sort(packages)
    local seen = {} ---@type table<string, boolean>
    packages = vim.tbl_filter(function(p)
      if seen[p] then
        return false
      end
      seen[p] = true
      return true
    end, packages)
    img.content = state.tpl(s.math.latex.tpl, {
      font_size = s.math.latex.font_size or "large",
      packages = table.concat(packages, ", "),
      header = M.get_header(ctx.bufnr),
      color = fg:upper():sub(2),
      content = content,
    })
  end,
}

---@type fml.dressing.image.Hover|nil
local hover = nil

local uv = vim.uv

---@type table<string, boolean>
local dir_cache = {}

---@type table<integer, {tick: integer, [string]: any}>
local bufnr_cache = {}

---@param bufnr                          integer
---@param key                            string
---@param fn                             fun(): any
---@return any
local function cache(bufnr, key, fn)
  if bufnr_cache[bufnr] and bufnr_cache[bufnr].tick ~= vim.api.nvim_buf_get_changedtick(bufnr) then
    bufnr_cache[bufnr] = nil
  end
  bufnr_cache[bufnr] = bufnr_cache[bufnr] or { tick = vim.api.nvim_buf_get_changedtick(bufnr) }
  if bufnr_cache[bufnr][key] == nil then
    bufnr_cache[bufnr][key] = fn()
  end
  return bufnr_cache[bufnr][key]
end

---@param bufnr                          integer
---@return string[]
function M.get_packages(bufnr)
  if vim.bo[bufnr].filetype ~= "tex" then
    return {}
  end
  return cache(bufnr, "packages", function()
    local ret = {} ---@type string[]
    for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
      line = line:match("(.-)%%") or line
      if line:find("\\usepackage", 1, true) then
        for _, p in ipairs(vim.split(line:match("\\usepackage.-{(.-)}") or "", ",%s*")) do
          if not vim.tbl_contains(ret, p) then
            ret[#ret + 1] = p
          end
        end
      elseif line:find("\\begin{document}", 1, true) then
        break
      end
    end
    return ret
  end)
end

---@param bufnr                          integer
---@return string
function M.get_header(bufnr)
  return cache(bufnr, "header", function()
    local header = {} ---@type string[]
    local in_header = false
    for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
      if line:find("snacks:%s*header%s*start") then
        in_header = true
      elseif line:find("snacks:%s*header%s*end") then
        in_header = false
      elseif in_header then
        header[#header + 1] = line
      end
    end
    return table.concat(header, "\n")
  end)
end

---@param bufnr                          integer
---@return table<string, string>
function M.get_link_definitions(bufnr)
  return cache(bufnr, "link_definitions", function()
    local ret = {} ---@type table<string, string>
    local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
    if not ok or not parser then
      return ret
    end
    local query = vim.treesitter.query.get("markdown", "link_definition")
    if not query then
      return ret
    end
    parser:for_each_tree(function(tstree, tree)
      if not tstree or tree:lang() ~= "markdown" then
        return
      end
      for _, match in query:iter_matches(tstree:root(), bufnr) do
        local label, dest ---@type string?, string?
        for id, nodes in pairs(match) do
          nodes = type(nodes) == "userdata" and { nodes } or nodes
          local name = query.captures[id]
          if name == "linkDefinition.label" then
            label = vim.treesitter.get_node_text(nodes[1], bufnr):lower():gsub("^%[", ""):gsub("%]$", "")
          elseif name == "linkDefinition.dest" then
            dest = vim.treesitter.get_node_text(nodes[1], bufnr)
          end
        end
        if label and dest then
          ret[label] = dest
        end
      end
    end)
    return ret
  end)
end

---@param dir                            string
---@return boolean
function M.is_dir(dir)
  if dir_cache[dir] == nil then
    dir_cache[dir] = vim.fn.isdirectory(dir) == 1
  end
  return dir_cache[dir]
end

---@param bufnr                          integer
---@param src                            string
---@return string
function M.resolve(bufnr, src)
  local s = require("fml.dressing.image.state").data
  local file = era.path.normalize(vim.api.nvim_buf_get_name(bufnr))
  local resolved = s.resolve and s.resolve(file, src) or nil
  if resolved then
    return resolved
  end
  local cwd = uv.cwd() or "."
  local checks = { [src] = true }
  for _, root in ipairs({ cwd, vim.fs.dirname(file) }) do
    checks[root .. "/" .. src] = true
    for _, dir in ipairs(s.img_dirs) do
      dir = root .. "/" .. dir
      if M.is_dir(dir) then
        checks[dir .. "/" .. src] = true
      end
    end
  end
  for f in pairs(checks) do
    if vim.fn.filereadable(f) == 1 then
      src = uv.fs_realpath(f) or f
      break
    end
  end
  return era.path.normalize(src)
end

---@param ctx                            fml.dressing.image.ctx
---@return fml.dressing.image.match|nil
local function make_img(ctx)
  local s = require("fml.dressing.image.state").data
  ctx.pos = ctx.pos or ctx.src or ctx.content or ctx.ref
  assert(ctx.pos, "no image node")

  local range6 = vim.treesitter.get_range(ctx.pos.node, ctx.bufnr, ctx.pos.meta)
  local range = { range6[1], range6[2], range6[4], range6[5] } ---@type integer[]
  if range[3] > 0 and range[4] == 0 then
    range[3] = range[3] - 1
    local line = vim.api.nvim_buf_get_lines(ctx.bufnr, range[3], range[3] + 1, false)[1]
    range[4] = #line
  end
  ---@type fml.dressing.image.match
  local img = {
    ext = ctx.meta[META_EXT],
    src = ctx.meta[META_SRC],
    lang = ctx.lang,
    id = ctx.pos.node:id(),
    range = { range[1] + 1, range[2], range[3] + 1, range[4] },
    pos = { range[1] + 1, range[2] },
    type = "image",
  }
  if ctx.meta[META_TYPE] then
    img.type = ctx.meta[META_TYPE]
  elseif img.ext then
    img.type = img.ext:match("^(%w+)%.") or img.type
  end
  if not s.math.enabled and img.type == "math" then
    return
  end
  if ctx.definition then
    img.src = ctx.definition.dest
  elseif ctx.src then
    img.src = vim.treesitter.get_node_text(ctx.src.node, ctx.bufnr, { metadata = ctx.src.meta })
  end
  if ctx.content then
    img.content = vim.treesitter.get_node_text(ctx.content.node, ctx.bufnr, { metadata = ctx.content.meta })
  end
  if not img.src and not img.content then
    return nil
  end

  local transform = M.transforms[ctx.lang]
  if transform then
    transform(img, ctx)
  end
  if img.src then
    img.src = M.resolve(ctx.bufnr, img.src)
  end
  if img.content and not img.src then
    local root = s.tmpdir
    dot.env.mkdirs(root, true)
    img.src = root
      .. "/"
      .. (img.content_id or vim.fn.sha256(img.content):sub(1, 8))
      .. "-content."
      .. (img.ext or "png")
    if vim.fn.filereadable(img.src) == 0 then
      local fd = assert(io.open(img.src, "w"), "failed to open " .. img.src)
      fd:write(img.content)
      fd:close()
    end
  end
  return img
end

---@param bufnr                          integer
---@param cb                             fml.dressing.image.find
---@return nil
function M.find_visible(bufnr, cb)
  local ret = {} ---@type table<string, fml.dressing.image.match>
  local wins = vim.fn.win_findbuf(bufnr)
  local count = #wins
  for _, winnr in ipairs(wins) do
    local info = vim.fn.getwininfo(winnr)[1]
    M.find(bufnr, function(matches)
      for _, i in ipairs(matches) do
        ret[i.id] = i
      end
      count = count - 1
      if count == 0 and cb then
        cb(vim.tbl_values(ret))
      end
    end, { from = math.max(info.topline - 1, 1), to = info.botline })
  end
end

---@param bufnr                          integer
---@param cb                             fml.dressing.image.find
---@param opts                           ?{from?: integer, to?: integer}
---@return nil
function M.find(bufnr, cb, opts)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then
    return cb({})
  end
  opts = opts or {}
  local from, to = opts.from, opts.to
  local link_definitions = M.get_link_definitions(bufnr)

  local function parse_callback()
    local ret = {} ---@type fml.dressing.image.match[]
    parser:for_each_tree(function(tstree, tree)
      if not tstree then
        return
      end
      local query = vim.treesitter.query.get(tree:lang(), "images")
      if not query then
        return
      end
      for _, match, meta in query:iter_matches(tstree:root(), bufnr, from and from - 1 or nil, to) do
        if not meta[META_IGNORE] then
          ---@type fml.dressing.image.ctx
          local ctx = {
            bufnr = bufnr,
            lang = tostring(meta[META_LANG] or meta["injection.language"] or tree:lang()),
            meta = meta,
          }
          for id, nodes in pairs(match) do
            nodes = type(nodes) == "userdata" and { nodes } or nodes
            local name = query.captures[id]
            local field = name == "image" and "pos" or name:match("^image%.(.*)$")
            if field then
              ---@diagnostic disable-next-line: assign-type-mismatch
              ctx[field] = { node = nodes[1], meta = meta[id] or {} }
            end
          end
          if ctx.ref then
            local ref_text = vim.treesitter.get_node_text(ctx.ref.node, bufnr):lower():gsub("^%[", ""):gsub("%]$", "")
            local dest = link_definitions[ref_text]
            if dest then
              ctx.definition = { label = ref_text, dest = dest }
            else
              meta[META_IGNORE] = true
            end
          end
          if not meta[META_IGNORE] then
            local img = make_img(ctx)
            if img then
              ret[#ret + 1] = img
            end
          end
        end
      end
    end)
    cb(ret)
  end

  if from and to then
    vim.treesitter.get_parser(bufnr):parse({ from, to })
    parse_callback()
  else
    vim.treesitter.get_parser(bufnr):parse(true)
    parse_callback()
  end
end

---@return nil
function M.hover_close()
  if hover then
    if vim.api.nvim_win_is_valid(hover.winnr) then
      vim.api.nvim_win_close(hover.winnr, true)
    end
    hover.img:close()
    hover = nil
  end
end

---@param cb                             fun(image_src?: string, image_pos?: fml.dressing.image.Pos)
---@return nil
function M.at_cursor(cb)
  local cursor = vim.api.nvim_win_get_cursor(0)
  M.find(vim.api.nvim_get_current_buf(), function(imgs)
    for _, img in ipairs(imgs) do
      local range = img.range
      if range then
        if
          (range[1] == range[3] and cursor[2] >= range[2] and cursor[2] <= range[4])
          or (range[1] ~= range[3] and cursor[1] >= range[1] and cursor[1] <= range[3])
        then
          return cb(img.src, img.pos)
        end
      end
    end
    cb()
  end, { from = cursor[1], to = cursor[1] + 1 })
end

---@return nil
function M.hover()
  local current_winnr = vim.api.nvim_get_current_win()
  local current_bufnr = vim.api.nvim_get_current_buf()

  if hover and hover.winnr == current_winnr and vim.api.nvim_win_is_valid(hover.winnr) then
    return
  end

  if hover and (hover.bufnr ~= current_bufnr or vim.fn.mode() ~= "n") then
    return M.hover_close()
  end

  if hover and not vim.api.nvim_win_is_valid(hover.winnr) then
    M.hover_close()
  end

  M.at_cursor(function(src)
    if not src then
      return M.hover_close()
    end

    if hover and hover.img.img.src ~= src then
      M.hover_close()
    elseif hover then
      hover.img:update()
      return
    end

    local s = require("fml.dressing.image.state").data
    local placement = require("fml.dressing.image.placement")

    local bufnr = vim.api.nvim_create_buf(false, true)
    local winnr = vim.api.nvim_open_win(bufnr, false, {
      relative = "cursor",
      row = 1,
      col = 1,
      width = 40,
      height = 20,
      style = "minimal",
      border = "rounded",
      focusable = false,
    })

    local updated = false
    local o = vim.tbl_deep_extend("force", {}, s.doc, {
      on_update_pre = function()
        if hover and not updated then
          updated = true
          local loc = hover.img:state().loc
          vim.api.nvim_win_set_config(winnr, {
            width = loc.width,
            height = loc.height,
          })
        end
      end,
      inline = false,
    })
    o.max_width = o.max_width or 80
    o.max_height = o.max_height or 40

    hover = {
      winnr = winnr,
      bufnr = current_bufnr,
      img = placement.new(bufnr, src, o),
    }
    vim.api.nvim_create_autocmd({ "BufWritePost", "CursorMoved", "ModeChanged", "BufLeave" }, {
      group = vim.api.nvim_create_augroup(__module_name__ .. ".hover", { clear = true }),
      callback = function()
        if not hover then
          return true
        end
        M.hover()
        if not hover then
          return true
        end
      end,
    })
  end)
end

---@param bufnr                          integer
---@return nil
function M.attach(bufnr)
  if not era.context.flight.dressing_image:snapshot() then
    return
  end
  if vim.b[bufnr].fml_image_attached then
    return
  end
  vim.b[bufnr].fml_image_attached = true

  local state_mod = require("fml.dressing.image.state")
  local inline_mod = require("fml.dressing.image.inline")
  local s = state_mod.data

  local inline = s.doc.inline and state_mod.env.placeholders
  local float = s.doc.float and not inline

  if not inline and not float then
    return
  end

  if inline then
    inline_mod.new(bufnr)
  else
    local group = vim.api.nvim_create_augroup(__module_name__ .. ".doc." .. bufnr, { clear = true })
    vim.api.nvim_create_autocmd({ "CursorMoved" }, {
      group = group,
      buffer = bufnr,
      callback = vim.schedule_wrap(M.hover),
    })
    vim.schedule(M.hover)
  end
end

return M
