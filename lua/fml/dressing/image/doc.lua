local fn = require("eve.builtin.fn")
local state = require("eve.state")
local config = require("fml.dressing.image.config")
local Placement = require("fml.dressing.image.placement")

---@class fml.dressing.image.doc
local M = {}

---@alias TSMatch {node:TSNode, meta:vim.treesitter.query.TSMetadata}
---@alias fml.dressing.image.transform fun(match: fml.dressing.image.match, ctx: fml.dressing.image.ctx)

---@class fml.dressing.image.Hover
---@field public placement              fml.dressing.image.Placement
---@field public winnr                  integer
---@field public bufnr                  integer

---@class fml.dressing.image.ctx
---@field public bufnr                  integer
---@field public lang                   string
---@field public meta                   vim.treesitter.query.TSMetadata
---@field public pos                    ?TSMatch
---@field public src                    ?TSMatch
---@field public content                ?TSMatch

---@class fml.dressing.image.match
---@field public id                     string
---@field public pos                    fml.dressing.image.Pos
---@field public ref                    ?string
---@field public src                    ?string
---@field public content                ?string
---@field public ext                    ?string
---@field public range                  ?Range4

local META_EXT = "image.ext"
local META_SRC = "image.src"
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
    if not img.content then
      return
    end
    local fg = fn.pick_color({ "SnacksImageMath" }, "fg") or "#000000"
    img.ext = "math.tex"
    local content = vim.trim(img.content or "")
    content = content:gsub("^%$+`?", ""):gsub("`?%$+$", "")
    content = content:gsub("^\\[%[%(]", ""):gsub("\\[%]%)]$", "")
    if not content:find("^\\begin") then
      content = ("\\[%s\\]"):format(content)
    end
    local packages = { "xcolor" }
    vim.list_extend(packages, config.state.math.latex.packages)
    for _, line in ipairs(vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)) do
      if line:find("\\usepackage") then
        for _, p in ipairs(vim.split(line:match("{(.-)}") or "", ",%s*")) do
          if not vim.tbl_contains(packages, p) then
            packages[#packages + 1] = p
          end
        end
      end
    end
    table.sort(packages)
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

---@param buf number
function M.get_header(buf)
  local header = {} ---@type string[]
  local in_header = false
  for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    if line:find("snacks:%s*header%s*start") then
      in_header = true
    elseif line:find("snacks:%s*header%s*end") then
      in_header = false
    elseif in_header then
      header[#header + 1] = line
    end
  end
  return table.concat(header, "\n")
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
---@return table<string,{label:string,dest:string}>
function M.get_link_definitions(bufnr)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then
    return {}
  end
  parser:parse()
  local refs = {}
  parser:for_each_tree(function(tstree, tree)
    if not tstree then
      return
    end
    local query = vim.treesitter.query.get(tree:lang(), "link_definition")
    if not query then
      return
    end
    for _, match in query:iter_matches(tstree:root(), bufnr) do
      -- Look for linkDefinition matches
      for id in pairs(match) do
        local name = query.captures[id]
        if name == "linkDefinition" then
          local label_node = nil
          local dest_node = nil
          -- Find the label and destination nodes
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
            refs[label] = { label = label, dest = dest }
          end
        end
      end
    end
  end)
  return refs
end

---@param bufnr                         integer
---@param from                          ?integer
---@param to                            ?integer
function M.find(bufnr, from, to)
  local linkDefinitions = M.get_link_definitions(bufnr)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then
    return {}
  end
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

        for id, nodes in pairs(match) do
          nodes = type(nodes) == "userdata" and { nodes } or nodes
          local name = query.captures[id]
          local field = name == "image" and "pos" or name:match("^image%.(.*)$")
          if field then
            ---@diagnostic disable-next-line: assign-type-mismatch
            ctx[field] = { node = nodes[1], meta = meta[id] or {} }
          end
        end
        ret[#ret + 1] = M._img(ctx)
      end
    end
  end)
  return ret
end

---@param ctx fml.dressing.image.ctx
function M._img(ctx)
  ctx.pos = ctx.pos or ctx.src or ctx.content
  assert(ctx.pos, "no image node")

  local range = vim.treesitter.get_range(ctx.pos.node, ctx.bufnr, ctx.pos.meta)
  local lines = vim.api.nvim_buf_get_lines(ctx.bufnr, range[1], range[4] + 1, false)
  while #lines > 0 and vim.trim(lines[#lines]) == "" do
    table.remove(lines)
  end
  ---@type fml.dressing.image.match
  local img = {
    ext = ctx.meta[META_EXT],
    src = ctx.meta[META_SRC],
    id = ctx.pos.node:id(),
    range = { range[1] + 1, range[2], range[4] + 1, range[5] },
    pos = {
      range[1] + #lines,
      math.min(range[2], range[5]),
    },
  }
  img.pos[1] = math.min(img.pos[1], vim.api.nvim_buf_line_count(ctx.bufnr))
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
  if not config.state.math.enabled and img.ext and img.ext:find("math") then
    return
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
---@return string? image_src, fml.dressing.image.Pos? image_pos
function M.at_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local imgs = M.find(vim.api.nvim_get_current_buf(), cursor[1], cursor[1] + 1)
  for _, img in ipairs(imgs) do
    local range = img.range
    if range then
      if
        (range[1] == range[3] and cursor[2] >= range[2] and cursor[2] <= range[4])
        or (range[1] ~= range[3] and cursor[1] >= range[1] and cursor[1] <= range[3])
      then
        return img.src, img.pos
      end
    end
  end
end

---@return nil
function M.hover()
  local winblend = state.theme.transparency:snapshot() and 0 or 10 ---@type integer
  local winnr_cur = vim.api.nvim_get_current_win() ---@type integer
  local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer

  if hover and hover.winnr == winnr_cur then
    return
  end

  if
    hover
    and hover.winnr > 0
    and vim.api.nvim_win_is_valid(hover.winnr)
    and (hover.bufnr ~= bufnr_cur or vim.fn.mode() ~= "n")
  then
    M.hover_close()
  end

  local src = M.at_cursor()
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

  if hover and hover.bufnr > 0 and vim.api.nvim_buf_is_valid(hover.bufnr) then
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
  if hover and hover.winnr > 0 and vim.api.nvim_win_is_valid(hover.winnr) then
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
        if hover.winnr > 0 and vim.api.nvim_win_is_valid(hover.winnr) then
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
    group = vim.api.nvim_create_augroup("fml.dressing.image.hover", { clear = true }),
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
end

---@return nil
function M.hover_close()
  if hover then
    if hover.winnr > 0 and vim.api.nvim_win_is_valid(hover.winnr) then
      vim.api.nvim_win_close(hover.winnr, true)
    end
    hover.placement:close()
    hover = nil
  end
end

---@param bufnr                         integer
---@return nil
function M.inline(bufnr)
  local imgs = {} ---@type table<string, fml.dressing.image.Placement>
  return function()
    local found = {} ---@type table<string, boolean>
    for _, i in ipairs(M.find(bufnr)) do
      local img = imgs[i.id] ---@type fml.dressing.image.Placement?
      if img and img.image.src ~= i.src then
        img:close()
        img = nil
      end

      if not img then
        img = Placement.new(
          bufnr,
          i.src,
          fn.merge_config({}, config.state.doc, { pos = i.pos, range = i.range, inline = true })
        )
        imgs[i.id] = img
      else
        img:update()
      end
      found[i.id] = true
    end
    for nid, img in pairs(imgs) do
      if not found[nid] then
        img:close()
        imgs[nid] = nil
      end
    end
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

  local group = vim.api.nvim_create_augroup("fml.dressing.image.doc." .. bufnr, { clear = true })
  local update = inline and M.inline(bufnr) or M.hover

  if inline then
    vim.api.nvim_create_autocmd("BufWritePost", {
      group = group,
      buffer = bufnr,
      callback = vim.schedule_wrap(update),
    })
  else
    vim.api.nvim_create_autocmd({ "CursorMoved" }, {
      group = group,
      buffer = bufnr,
      callback = vim.schedule_wrap(update),
    })
  end
  vim.schedule(update)
end

return M
