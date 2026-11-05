---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.image.doc" ---@type string

---@class era.m.image.doc : era.m.image.inline.IDocument
local M = {}

---@alias TSMatch                        {node: TSNode, meta: vim.treesitter.query.TSMetadata}

---@alias era.m.image.transform   fun(match: era.m.image.match, ctx: era.m.image.ctx)

---@alias era.m.image.find        fun(matches: era.m.image.match[])

---@alias LinkDefinition                 {label: string, dest: string}

---@class era.m.image.ctx
---@field public bufnr                   integer
---@field public lang                    string
---@field public meta                    vim.treesitter.query.TSMetadata
---@field public pos                     ?TSMatch
---@field public src                     ?TSMatch
---@field public content                 ?TSMatch
---@field public ref                     ?TSMatch
---@field public definition              ?LinkDefinition

---@class era.m.image.match
---@field public id                      string
---@field public pos                     era.m.image.Pos
---@field public src                     ?string
---@field public content                 ?string
---@field public content_id              ?string
---@field public ext                     ?string
---@field public range                   ?integer[]
---@field public lang                    string
---@field public type                    era.m.image.Type

local META_EXT = "image.ext"
local META_SRC = "image.src"
local META_TYPE = "image.type"
local META_IGNORE = "image.ignore"
local META_LANG = "image.lang"

---@type table<string, era.m.image.transform>
M.transforms = {
  norg = function(img, ctx)
    local row, col = ctx.src.node:start()
    local line = vim.api.nvim_buf_get_lines(ctx.bufnr, row, row + 1, false)[1]
    img.src = line:sub(col + 1)
  end,
  latex = function(img, ctx)
    local state = require("era.m.image.state")
    local s = state.data
    if not (img.content and img.ext == "math.tex") then
      return
    end
    local color_val = vim.api.nvim_get_hl(0, { name = "m_img_math" }).fg
    local fg = color_val and string.format("#%06x", color_val) or "#000000"
    local content = vim.trim(img.content or "")
    -- `$…$` and `\(…\)` sit in a line of text and are set in text style, as a web page does; `$$…$$` and `\[…\]` are
    -- displayed.
    local inline = content:find("^%$[^$]") ~= nil or content:find("^\\%(") ~= nil
    content = content:gsub("^%$+`?", ""):gsub("`?%$+$", "")
    content = content:gsub("^\\[%[%(]", ""):gsub("\\[%]%)]$", "")
    if not content:find("^\\begin") then
      content = (inline and "$%s$" or "\\[%s\\]"):format(content)
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
    img.content = state.tpl_env(s.math.latex.tpl, {
      font_size = s.math.latex.font_size or "large",
      packages = table.concat(packages, ", "),
      header = M.get_header(ctx.bufnr),
      color = fg:upper():sub(2),
      content = content,
    })
  end,
}

local uv = vim.uv

---@type table<string, boolean>
local dir_cache = {}

---@type table<integer, {tick: integer, [string]: any}>
local bufnr_cache = {}

---The inline renderer of each buffer; one that was disposed is replaced when its buffer is attached again.
---@type table<integer, era.m.image.inline>
local inlines = setmetatable({}, { __mode = "v" })

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
  if vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ~= "tex" then
    return {}
  end
  return cache(bufnr, "packages", function()
    local ret = {} ---@type string[]
    for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
      line = line:match("(.-)%%") or line
      if line:find("\\usepackage", 1, true) then
        for _, p in ipairs(vim.split(line:match("\\usepackage.-{(.-)}") or "", ",%s*")) do
          if not vim.list_contains(ret, p) then
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
        local label, dest ---@type string|nil, string|nil
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

---Where `src` points from the document `bufnr`. The document's directory comes before the working directory, and a
---file that does not exist yet is named next to the document, where it is most likely to appear.
---@param bufnr                          integer
---@param src                            string
---@return string
function M.resolve(bufnr, src)
  local s = require("era.m.image.state").data
  local file = dot.path.normalize(vim.api.nvim_buf_get_name(bufnr))
  local resolved = s.resolve and s.resolve(file, src) or nil
  if resolved then
    return resolved
  end
  -- URLs and data URIs are no files; normalizing one would even fold the `//` that base64 data contains.
  if src:find("^data:") or (src:find("^%a[%w+.-]*://") and not src:find("^file://")) then
    return src
  end
  -- A link destination escapes spaces and the like (`my%20image.png`); `#page=` selects a page of a PDF.
  local path = src:find("^file://") and vim.uri_to_fname(src) or yoz.uri.decode(src) ---@type string
  local page = path:match("#page=%d+$") or "" ---@type string
  path = path:sub(1, #path - #page)
  local candidates = {} ---@type string[]
  if path:find("^[/~]") then
    candidates[1] = path
  else
    for _, root in ipairs({ vim.fs.dirname(file), uv.cwd() or "." }) do
      candidates[#candidates + 1] = root .. "/" .. path
      for _, dir in ipairs(s.img_dirs) do
        dir = root .. "/" .. dir
        if M.is_dir(dir) then
          candidates[#candidates + 1] = dir .. "/" .. path
        end
      end
    end
  end
  for _, candidate in ipairs(candidates) do
    if vim.fn.filereadable(candidate) == 1 then
      return dot.path.normalize(uv.fs_realpath(candidate) or candidate) .. page
    end
  end
  return dot.path.normalize(candidates[1]) .. page
end

---@param bufnr                          integer
---@return boolean Whether inline math should render in `bufnr`: needs the math feature and the
--- `dressing_image` flight on, plus render-markdown effectively rendering this buffer — which
--- mirrors its global enable/disable AND the per-buffer `<leader>um` (`buf_toggle`). Falls back
--- to the global `render_markdown` flag if render-markdown's internals ever move (pcall-guarded).
function M.math_enabled(bufnr)
  local s = require("era.m.image.state").data
  if not s.math.enabled or not dot.context.flight.dressing_image:snapshot() then
    return false
  end
  local ok_m, manager = pcall(require, "render-markdown.core.manager")
  local ok_s, rm_state = pcall(require, "render-markdown.state")
  if ok_m and ok_s and bufnr then
    return manager.attached(bufnr) and rm_state.get(bufnr).enabled == true
  end
  return dot.context.plugin.render_markdown:snapshot()
end

---@param ctx                            era.m.image.ctx
---@return era.m.image.match|nil
local function make_img(ctx)
  local s = require("era.m.image.state").data
  ctx.pos = ctx.pos or ctx.src or ctx.content or ctx.ref
  assert(ctx.pos, "no image node")

  local range6 = vim.treesitter.get_range(ctx.pos.node, ctx.bufnr, ctx.pos.meta)
  local range = { range6[1], range6[2], range6[4], range6[5] } ---@type integer[]
  if range[3] > 0 and range[4] == 0 then
    range[3] = range[3] - 1
    local line = vim.api.nvim_buf_get_lines(ctx.bufnr, range[3], range[3] + 1, false)[1]
    range[4] = #line
  end
  ---@type era.m.image.match
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
  if img.type == "math" and not M.math_enabled(ctx.bufnr) then
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
    stl.env.mkdirs(root, true)
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
---@param cb                             era.m.image.find
---@return nil
function M.find_visible(bufnr, cb)
  local ret = {} ---@type table<string, era.m.image.match>
  local wins = vim.fn.win_findbuf(bufnr)
  local count = #wins
  for _, winnr in ipairs(wins) do
    local info = vim.fn.getwininfo(winnr)[1]
    -- Up to the line after `botline`, the last line shown whole: that one may show in part.
    M.find(bufnr, function(matches)
      for _, i in ipairs(matches) do
        ret[i.id] = i
      end
      count = count - 1
      if count == 0 and cb then
        cb(vim.tbl_values(ret))
      end
    end, { from = math.max(info.topline - 1, 1), to = info.botline + 1 })
  end
end

---@param bufnr                          integer
---@param cb                             era.m.image.find
---@param opts                           ?{from?: integer, to?: integer}
---@return nil
function M.find(bufnr, cb, opts)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then
    return cb({})
  end
  opts = opts or {}
  local from, to = opts.from, opts.to

  local function parse_callback()
    local ret = {} ---@type era.m.image.match[]
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
          ---@type era.m.image.ctx
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
            -- Scanned only for a reference image: the definitions can be anywhere, so each edit rescans the whole
            -- document.
            local dest = M.get_link_definitions(bufnr)[ref_text]
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
    parser:parse({ from, to })
    parse_callback()
  else
    parser:parse(true)
    parse_callback()
  end
end

---@param bufnr                          integer
---@return nil
function M.attach(bufnr)
  -- Attached whatever the `dressing_image` flight says: the renderer follows it, so turning it on shows the images.
  local current = inlines[bufnr]
  if current and not current.disposed then
    return
  end
  inlines[bufnr] = require("era.m.image.inline").new(bufnr, M)
end

return M
