local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new()

bootstrap.with_native(t)
bootstrap.with_runtime(t, {
  dot = {
    path = {
      -- As `dot.path.normalize` does.
      normalize = function(path)
        return yoz.path.normalize(path, true, "/")
      end,
    },
  },
})

t:patch_table(package.loaded, "era.m.image.state", { data = { img_dirs = {} } })

---A markdown buffer of `lines` named `doc.md` in `dir`.
---@param dir                           string
---@param lines                         string[]
---@param current                       ?boolean Shown in the current window.
---@return integer
local function markdown(dir, lines, current)
  return t:buffer(lines, { name = dir .. "/doc.md", filetype = "markdown", current = current })
end

---@param document                      era.m.image.doc
---@param bufnr                         integer
---@return string[]
local function sources(document, bufnr)
  local found = {} ---@type era.m.image.match[]
  document.find(bufnr, function(imgs)
    found = imgs
  end)
  table.sort(found, function(a, b)
    return a.pos[1] < b.pos[1]
  end)
  return vim.tbl_map(function(img)
    return img.src
  end, found)
end

t:test("a document without reference images never scans its link definitions", function()
  local document = assert(loadfile("lua/era/m/image/doc.lua"))()
  local scans = 0 ---@type integer
  t:patch_table(document, "get_link_definitions", function()
    scans = scans + 1
    return {}
  end)
  local dir = t:tempdir() ---@type string

  local bufnr = markdown(dir, { "![alt](a.png)", "", "![](b.png)", "", '![alt](c.png "title")' })

  t.assert_same({ dir .. "/a.png", dir .. "/b.png", dir .. "/c.png" }, sources(document, bufnr), "images")
  t.assert_eq(0, scans, "link definition scans")
end)

t:test("reference images resolve through the link definitions", function()
  local document = assert(loadfile("lua/era/m/image/doc.lua"))()
  local dir = t:tempdir() ---@type string
  local bufnr = markdown(dir, { "![full][logo]", "", "![logo][]", "", "![logo]", "", "[logo]: images/logo.png" })

  local logo = dir .. "/images/logo.png" ---@type string
  t.assert_same({ logo, logo, logo }, sources(document, bufnr), "images")
end)

t:test("a relative image is looked up next to the document before the working directory", function()
  local document = assert(loadfile("lua/era/m/image/doc.lua"))()
  local cwd = t:tempdir() ---@type string
  local dir = cwd .. "/docs" ---@type string
  vim.fn.mkdir(dir, "p")
  for _, file in ipairs({ cwd .. "/logo.png", dir .. "/logo.png", dir .. "/my image.png" }) do
    vim.fn.writefile({ "png" }, file)
  end
  local previous = assert(vim.uv.cwd()) ---@type string
  vim.api.nvim_set_current_dir(cwd)
  t:defer(function()
    vim.api.nvim_set_current_dir(previous)
  end)
  local bufnr = markdown(dir, {})

  t.assert_eq(dir .. "/logo.png", document.resolve(bufnr, "logo.png"), "the document's directory first")
  t.assert_eq(dir .. "/my image.png", document.resolve(bufnr, "my%20image.png"), "escaped destination")
  t.assert_eq(dir .. "/later.png", document.resolve(bufnr, "later.png"), "a file that does not exist yet")
  t.assert_eq(dir .. "/logo.png#page=2", document.resolve(bufnr, "logo.png#page=2"), "page of a document")
end)

t:test("URLs and data URIs are no files and pass through unchanged", function()
  local document = assert(loadfile("lua/era/m/image/doc.lua"))()
  local bufnr = markdown(t:tempdir(), {})
  -- Base64 data often holds `//` or `/./`, which normalizing a path would fold.
  local data = "data:image/png;base64,iVBORw0KGgo//AAAA//8AAA/./x" ---@type string
  local url = "https://img.shields.io/badge/a-b-green.svg" ---@type string

  t.assert_eq(data, document.resolve(bufnr, data), "data URI")
  t.assert_eq(url, document.resolve(bufnr, url), "URL")
end)

t:test("the visible images include the line after the last one shown whole, which may show in part", function()
  local document = assert(loadfile("lua/era/m/image/doc.lua"))()
  local dir = t:tempdir() ---@type string
  local bufnr = markdown(dir, vim.fn["repeat"]({ "" }, 200), true)
  local botline = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1].botline ---@type integer
  vim.api.nvim_buf_set_lines(bufnr, botline, botline + 2, false, { "![](part.png)", "![](below.png)" })

  local found = {} ---@type string[]
  document.find_visible(bufnr, function(imgs)
    for _, img in ipairs(imgs) do
      found[#found + 1] = img.src
    end
  end)

  t.assert_same({ dir .. "/part.png" }, found, "images")
end)

t:test("a formula in a line of text is set in text style, a displayed one in display style", function()
  local document = assert(loadfile("lua/era/m/image/doc.lua"))()
  t:patch_table(package.loaded, "era.m.image.state", {
    data = { img_dirs = {}, math = { latex = { tpl = "${content}", packages = {} } } },
    tpl_env = function(tpl, data)
      return (tpl:gsub("%${(%w+)}", function(key)
        return tostring(data[key])
      end))
    end,
  })
  local bufnr = markdown(t:tempdir(), {})

  for source, latex in pairs({
    ["$\\frac{a}{b}$"] = "$\\frac{a}{b}$",
    ["\\(x^2\\)"] = "$x^2$",
    ["$$\\frac{a}{b}$$"] = "\\[\\frac{a}{b}\\]",
    ["\\[x^2\\]"] = "\\[x^2\\]",
  }) do
    local img = { content = source, ext = "math.tex" } ---@type era.m.image.match
    document.transforms.latex(img, { bufnr = bufnr })
    t.assert_eq(latex, img.content, source)
  end
end)

t:test("a formula's source is named after 64 bits of its hash and is the same in every theme", function()
  local document = assert(loadfile("lua/era/m/image/doc.lua"))()
  t:patch_table(package.loaded, "era.m.image.state", {
    -- A template that would show a color if the formula were given one.
    data = { img_dirs = {}, tmpdir = t:tempdir(), math = { latex = { tpl = "${color}${content}", packages = {} } } },
    tpl_env = function(tpl, data)
      return (tpl:gsub("%${(%w+)}", function(key)
        return tostring(data[key])
      end))
    end,
  })
  t:patch_table(document, "math_enabled", function()
    return true
  end)
  t:patch_table(stl, "env", {
    mkdirs = function(path)
      vim.fn.mkdir(path, "p")
    end,
  })
  t:defer(function()
    vim.api.nvim_set_hl(0, "m_img_math", {})
  end)
  local bufnr = markdown(t:tempdir(), { "```math", "x^2", "```" })

  local names = {} ---@type string[]
  for _, fg in ipairs({ 0x0078D4, 0xEB6F92 }) do
    vim.api.nvim_set_hl(0, "m_img_math", { fg = fg })
    names[#names + 1] = vim.fs.basename(sources(document, bufnr)[1] or "")
  end

  t.assert_eq(names[1], names[2], "every theme")
  t.assert_true(names[1]:match("^" .. ("%x"):rep(16) .. "%-content%.math%.tex$") ~= nil, names[1])
end)

t:run()
