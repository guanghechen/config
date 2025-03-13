local fn = require("eve.builtin.fn")
local state = require("eve.state")
local config = require("fml.dressing.image.config")
local Placement = require("fml.dressing.image.placement")
local ImageInline = require("fml.dressing.image.inline")

---@class fml.dressing.image.doc
local M = {}

---@alias fml.dressing.image.find       fun(matches: fml.dressing.image.match[])
---@alias fml.dressing.image.transform  fun(match: fml.dressing.image.match, ctx: fml.dressing.image.ctx)
---@alias LinkDefinition                {label:string, dest:string}
---@alias TSMatch                       {node:TSNode, meta:vim.treesitter.query.TSMetadata}

---@class fml.dressing.image.Hover
---@field public placement              fml.dressing.image.Placement
---@field public winnr                  integer
---@field public bufnr                  integer

---@class fml.dressing.image.ctx
---@field public bufnr                  integer
---@field public lang                   string
---@field public meta                   vim.treesitter.query.TSMetadata
---@field public pos                    ?TSMatch
---@field public ref                    ?TSMatch
---@field public src                    ?TSMatch
---@field public content                ?TSMatch
---@field public definition             ?LinkDefinition

---@class fml.dressing.image.match
---@field public id                     string
---@field public lang                   string
---@field public pos                    fml.dressing.image.Pos
---@field public type                   fml.dressing.image.Type
---@field public ref                    ?string
---@field public src                    ?string
---@field public content                ?string
---@field public ext                    ?string
---@field public range                  ?Range4

local META_EXT = "image.ext"
local META_REF = "image.ref"
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
    img.content = fn.tpl(config.state.math.typst.tpl, {
      color = fn.pick_color({ "SnacksImageMath" }, "fg") or "#000000",
      header = M.get_header(ctx.bufnr),
      content = img.content,
    }, { indent = true, prefix = "$" })
  end,
  latex = function(img, ctx)
    if not (img.content and img.ext == "math.tex") then
      return
    end
    local fg = fn.pick_color({ "SnacksImageMath" }, "fg") or "#000000"
    local content = vim.trim(img.content or "")
    content = content:gsub("^%$+`?", ""):gsub("`?%$+$", "")
    content = content:gsub("^\\[%[%(]", ""):gsub("\\[%]%)]$", "")
    if not content:find("^\\begin") then
      content = ("\\[%s\\]"):format(content)
    end
    local packages = { "xcolor" }
    vim.list_extend(packages, config.state.math.latex.packages)
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
    img.content = fn.tpl(config.state.math.latex.tpl, {
      font_size = config.state.math.latex.font_size or "large",
      packages = table.concat(packages, ", "),
      header = M.get_header(ctx.bufnr),
      color = fg:upper():sub(2),
      content = content,
    }, { indent = true, prefix = "$" })
  end,
}

local hover ---@type fml.dressing.image.Hover?
local uv = vim.uv or vim.loop
local dir_cache = {} ---@type table<string, boolean>
local buf_cache = {} ---@type table<number, {tick: number, [string]: any }>

---@generic T
---@param bufnr                         integer
---@param key                           string
---@param f                             fun(): T
---@return T
function M._cache(bufnr, key, f)
  if buf_cache[bufnr] and buf_cache[bufnr].tick ~= vim.api.nvim_buf_get_changedtick(bufnr) then
    buf_cache[bufnr] = nil
  end
  buf_cache[bufnr] = buf_cache[bufnr] or { tick = vim.api.nvim_buf_get_changedtick(bufnr) }
  if buf_cache[bufnr][key] == nil then
    buf_cache[bufnr][key] = f()
  end
  return buf_cache[bufnr][key]
end

---@param bufnr                         integer
---@return string[]
function M.get_packages(bufnr)
  if vim.bo[bufnr].filetype ~= "tex" then
    return {}
  end
  return M._cache(bufnr, "packages", function()
    local ret = {} ---@type string[]
    for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
      if line:find("\\usepackage", 1, true) then
        for _, p in ipairs(vim.split(line:match("{(.-)}") or "", ",%s*")) do
          if not vim.tbl_contains(ret, p) then
            ret[#ret + 1] = p
          end
        end
      end
    end
    return ret
  end)
end

---@param bufnr                         integer
function M.get_header(bufnr)
  return M._cache(bufnr, "header", function()
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

---@param str string
function M.url_decode(str)
  return str:gsub("+", " "):gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end)
end

---@param dir string
function M.is_dir(dir)
  if dir_cache[dir] == nil then
    dir_cache[dir] = vim.fn.isdirectory(dir) == 1
  end
  return dir_cache[dir]
end

---@param bufnr                         integer
---@param src                           string
---@return string
function M.resolve(bufnr, src)
  src = M.url_decode(src)
  local file = vim.fs.normalize(vim.api.nvim_buf_get_name(bufnr))
  if not src:find("^%w%w+://") then
    local cwd = uv.cwd() or "."
    local checks = { [src] = true }
    for _, root in ipairs({ cwd, vim.fs.dirname(file) }) do
      checks[root .. "/" .. src] = true
      for _, dir in ipairs(config.state.img_dirs) do
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
    src = vim.fs.normalize(src)
  end
  return src
end

---@param bufnr                         integer
---@return table<string, LinkDefinition>
function M.get_link_definitions(bufnr)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then
    return {}
  end
  parser:parse()
  local defitions = {}
  parser:for_each_tree(function(tstree, tree)
    if not tstree then
      return
    end
    local query = vim.treesitter.query.get(tree:lang(), "link_definition")
    if not query then
      return
    end
    for _, match in query:iter_matches(tstree:root(), bufnr) do
      for id in pairs(match) do
        local name = query.captures[id]
        if name == "linkDefinition" then
          local label_node = nil
          local dest_node = nil
          for inner_id, inner_nodes in pairs(match) do
            local inner_name = query.captures[inner_id]
            if inner_name == "linkDefinition.label" then
              label_node = inner_nodes
            elseif inner_name == "linkDefinition.dest" then
              dest_node = inner_nodes
            end
          end
          if label_node and dest_node then
            local label = vim.treesitter.get_node_text(label_node, bufnr):gsub("^%[(.-)%]$", "%1") ---@type string
            local dest = vim.treesitter.get_node_text(dest_node, bufnr) ---@type string
            local defintion = { label = label, dest = dest } ---@type LinkDefinition
            defitions[label] = defintion
          end
        end
      end
    end
  end)
  return defitions
end

---@param bufnr                         integer
---@param callback                      fml.dressing.image.find
function M.find_visible(bufnr, callback)
  local ret = {} ---@type table<string, fml.dressing.image.match>
  local winnrs = vim.fn.win_findbuf(bufnr) ---@type integer[]
  local count = #winnrs ---@type integer
  for _, win in ipairs(winnrs) do
    local info = vim.fn.getwininfo(win)[1]
    M.find(bufnr, function(mathes)
      for _, i in ipairs(mathes) do
        ret[i.id] = i
      end
      count = count - 1
      if count == 0 and callback then
        callback(vim.tbl_values(ret))
      end
    end, { from = math.max(info.topline - 1, 1), to = info.botline })
  end
end

---@param bufnr                         integer
---@param callback                      fml.dressing.image.find
---@param opts                          ?{ from?: integer, to?: integer }
function M.find(bufnr, callback, opts)
  local definitions = M.get_link_definitions(bufnr) ---@type table<string, LinkDefinition>
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then
    return callback({})
  end

  opts = opts or {}
  local from, to = opts.from, opts.to
  parser:parse(from and to and { from, to } or true)

  local ret = {} ---@type fml.dressing.image.match[]
  parser:for_each_tree(function(tstree, tree)
    if not tstree then
      return
    end
    local query = vim.treesitter.query.get(tree:lang(), "images")
    if not query then
      return
    end
    for _, match, meta in query:iter_matches(tstree:root(), bufnr, from and from - 1 or nil, to and to - 1 or nil) do
      if not meta[META_IGNORE] then
        ---@type fml.dressing.image.ctx
        local ctx = {
          bufnr = bufnr,
          lang = tostring(meta[META_LANG] or meta["injection.language"] or tree:lang()),
          meta = meta,
        }

        local ignored = false ---@type boolean
        for id, nodes in pairs(match) do
          nodes = type(nodes) == "userdata" and { nodes } or nodes
          local name = query.captures[id]
          if name == META_REF then
            local ref = vim.treesitter.get_node_text(nodes[1], bufnr, { metadata = meta[id] or {} })
            if ref ~= nil and definitions[ref] then
              ctx.ref = { node = nodes[1], meta = meta[id] or {} }
              ctx.definition = definitions[ref]
            else
              ignored = true
              break
            end
          else
            local field = name == "image" and "pos" or name:match("^image%.(.*)$")
            if field then
              ---@diagnostic disable-next-line: assign-type-mismatch
              ctx[field] = { node = nodes[1], meta = meta[id] or {} }
            end
          end
        end
        if not ignored then
          local img_match = M._img(ctx, ret)
          ret[#ret + 1] = img_match
        end
      end
    end
  end)
  callback(ret)
end

---@param ctx                           fml.dressing.image.ctx
---@param matches                       fml.dressing.image.match
---@return fml.dressing.image.match|nil
function M._img(ctx, matches)
  ctx.pos = ctx.pos or ctx.src or ctx.content or ctx.ref
  assert(ctx.pos, "no image node")

  local range6 = vim.treesitter.get_range(ctx.pos.node, ctx.bufnr, ctx.pos.meta)
  local range = { range6[1], range6[2], range6[4], range6[5] } ---@type Range4
  if range[3] > 0 and range[4] == 0 then
    range[3] = range[3] - 1
    local line = vim.api.nvim_buf_get_lines(ctx.bufnr, range[3], range[3] + 1, false)[1]
    range[4] = #line
  end

  ---@type fml.dressing.image.match
  local img = {
    ext = ctx.meta[META_EXT],
    src = ctx.definition and ctx.definition.dest or ctx.meta[META_SRC],
    lang = ctx.lang,
    id = ctx.pos.node:id(),
    range = { range[1] + 1, range[2], range[3] + 1, range[4] },
    pos = { range[1] + 1, range[2] },
    type = "image",
  }

  --- The `![A](./A.png)` could be resolved twice if the `A` is a valid definition label,
  --- so we need to deduplicate the items here.
  if #matches > 0 then
    local r1 = matches[#matches].range ---@type Range4
    local r2 = img.range ---@type Range4
    if r1[1] == r2[1] and r1[2] >= r2[2] and r1[3] == r2[3] and r1[4] <= r2[4] then
      matches[#matches] = nil
    end
  end

  if ctx.meta[META_TYPE] then
    img.type = ctx.meta[META_TYPE]
  elseif img.ext then
    img.type = img.ext:match("^(%w+)%.") or img.type
  end
  if not config.state.math.enabled and img.type == "math" then
    return
  end

  if ctx.src then
    img.src = vim.treesitter.get_node_text(ctx.src.node, ctx.bufnr, { metadata = ctx.src.meta })
  end
  if ctx.content then
    img.content = vim.treesitter.get_node_text(ctx.content.node, ctx.bufnr, { metadata = ctx.content.meta })
  end
  assert(img.src or img.content, "no image src or content")

  local transform = M.transforms[ctx.lang]
  if transform then
    transform(img, ctx)
  end
  if img.src then
    img.src = M.resolve(ctx.bufnr, img.src)
  end
  if img.content and not img.src then
    local root = config.state.cache
    vim.fn.mkdir(root, "p")
    img.src = root .. "/" .. vim.fn.sha256(img.content):sub(1, 8) .. "-content." .. (img.ext or "png")
    if vim.fn.filereadable(img.src) == 0 then
      local fd = assert(io.open(img.src, "w"), "failed to open " .. img.src)
      fd:write(img.content)
      fd:close()
    end
  end
  return img
end

--- Get the image at the cursor (if any)
---@param callback                      fun(image_src?: string, image_pos?: fml.dressing.image.Pos): nil
---@return nil
function M.at_cursor(callback)
  local cursor = vim.api.nvim_win_get_cursor(0)
  M.find(vim.api.nvim_get_current_buf(), function(imgs)
    for _, img in ipairs(imgs) do
      local range = img.range
      if range then
        if
          (range[1] == range[3] and cursor[2] >= range[2] and cursor[2] <= range[4])
          or (range[1] ~= range[3] and cursor[1] >= range[1] and cursor[1] <= range[3])
        then
          return callback(img.src, img.pos)
        end
      end
    end
    callback()
  end, { from = cursor[1], to = cursor[1] + 1 })
end

---@return nil
function M.hover()
  local winblend = state.theme.transparency:snapshot() and 0 or 10 ---@type integer
  local winnr_cur = vim.api.nvim_get_current_win() ---@type integer
  local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer

  if hover and hover.winnr == winnr_cur then
    return
  end

  if hover and eve.std.nvim.is_win_valid(hover.winnr) and (hover.bufnr ~= bufnr_cur or vim.fn.mode() ~= "n") then
    M.hover_close()
  end

  M.at_cursor(function(src)
    if not src then
      return M.hover_close()
    end

    if hover and hover.placement.image.src ~= src then
      M.hover_close()
    elseif hover then
      hover.placement:update()
      return
    end

    local bufnr = 0 ---@type integer
    local winnr = 0 ---@type integer

    if hover and eve.std.nvim.is_buf_valid(hover.bufnr) then
      bufnr = hover.bufnr
    else
      bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
      hover.bufnr = bufnr
    end

    ---@type vim.api.keyset.win_config
    local wincfg = {
      relative = "cursor",
      height = 40,
      width = 80,
      row = 1,
      col = 1,
      enter = false,
      focusable = false,
      backdrop = false,
      show = false,
      title = "Image Previewer",
      title_pos = "center",
      border = "rounded",
      style = "minimal",
    }
    if hover and eve.std.nvim.is_win_valid(hover.winnr) then
      winnr = hover.winnr ---@type integer
      vim.api.nvim_win_set_config(hover.winnr, wincfg)

      vim.wo[winnr].number = false
      vim.wo[winnr].relativenumber = false
      vim.wo[winnr].signcolumn = "no"
      vim.wo[winnr].cursorline = false
      vim.wo[winnr].winblend = winblend
      vim.wo[winnr].wrap = false

      vim.wo[winnr].winfixbuf = false
      vim.api.nvim_win_set_buf(winnr, bufnr)
      vim.wo[winnr].winfixbuf = true
    else
      winnr = vim.api.nvim_open_win(bufnr, true, wincfg) ---@type integer
      hover.winnr = winnr

      vim.wo[winnr].number = false
      vim.wo[winnr].relativenumber = false
      vim.wo[winnr].signcolumn = "no"
      vim.wo[winnr].cursorline = false
      vim.wo[winnr].winblend = winblend
      vim.wo[winnr].wrap = false
      vim.wo[winnr].winfixbuf = true
    end

    local updated = false
    local o = fn.merge_config({}, config.state.doc, {
      on_update_pre = function()
        if hover and not updated then
          updated = true
          local loc = hover.placement:state().loc
          if eve.std.nvim.is_win_valid(hover.winnr) then
            vim.api.nvim_win_set_height(hover.winnr, loc.height)
            vim.api.nvim_win_set_width(hover.winnr, loc.width)
          end
        end
      end,
      inline = false,
    })

    hover = {
      winnr = winnr,
      bufnr = bufnr,
      placement = Placement.new(bufnr, src, o),
    }

    vim.api.nvim_create_autocmd({ "BufWritePost", "CursorMoved", "ModeChanged", "BufLeave" }, {
      group = eve.std.nvim.augroup("fml.dressing.image.hover"),
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

---@return nil
function M.hover_close()
  if hover then
    if eve.std.nvim.is_win_valid(hover.winnr) then
      vim.api.nvim_win_close(hover.winnr, true)
    end
    hover.placement:close()
    hover = nil
  end
end

---@param bufnr                         integer
---@return nil
function M.attach(bufnr)
  if vim.b[bufnr].fml_image_attached then
    return
  end
  vim.b[bufnr].fml_image_attached = true

  local inline = config.state.doc.inline and config.resolve_env().placeholders ---@type boolean
  local float = config.state.doc.float and not inline ---@type boolean
  if not inline and not float then
    return
  end

  if inline then
    ImageInline.new(bufnr)
  else
    local group = eve.std.nvim.augroup("fml.dressing.image.doc." .. bufnr)
    vim.api.nvim_create_autocmd({ "CursorMoved" }, {
      group = group,
      buffer = bufnr,
      callback = vim.schedule_wrap(M.hover),
    })
    vim.schedule(M.hover)
  end
end

return M
