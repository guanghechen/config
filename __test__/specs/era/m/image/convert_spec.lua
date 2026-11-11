local bootstrap = require("__test__.support.bootstrap")
local fs = require("__test__.support.fs")
local harness = require("__test__.support.harness")

local t = harness.new()

bootstrap.with_native(t)
bootstrap.with_runtime(t, {
  dot = {
    path = {
      join = function(left, right)
        return yoz.path.join(left, right, true, "/")
      end,
      normalize = function(path)
        return yoz.path.normalize(path, true, "/")
      end,
    },
  },
  stl = {
    c = { Proc = require("stl.c.proc") },
    env = {
      IS_GHOSTTY = false,
      IS_KITTY = false,
      IS_TMUX = false,
      IS_WIN = false,
      mkdirs = function(path)
        vim.fn.mkdir(path, "p")
      end,
    },
    table = require("stl.table"),
  },
})

---Writes the shell script `lines` as the executable `name` in `dir`.
---@param dir                           string
---@param name                          string
---@param lines                         string[]
---@return nil
local function executable(dir, name, lines)
  fs.write(dir .. "/" .. name, lines)
  vim.fn.setfperm(dir .. "/" .. name, "rwxr-xr-x")
end

-- Conversions run this `magick`, which hangs on any file whose name says so. Like the real one, a conversion
-- writes the image after `-write` (unless to memory) and its identification to the last argument, in the format a
-- prefix may name. Each run logs its arguments.
local bin = t:tempdir() ---@type string
executable(bin, "magick", {
  "#!/bin/sh",
  "printf '%s\\n' \"$*\" >> '" .. bin .. "/runs.log'",
  'case "$*" in',
  "  *slow*) exec sleep 30 ;;",
  "esac",
  'if [ "$1" = identify ]; then',
  "  echo 'PNG 4x2 96x96'",
  "  exit 0",
  "fi",
  'prev=""',
  'for arg in "$@"; do',
  '  [ "$prev" = "-write" ] && case "$arg" in mpr:*) ;; *) printf png > "$arg" ;; esac',
  '  prev="$arg"',
  "done",
  'case "$prev" in [A-Z]*:*) prev="${prev#*:}" ;; esac',
  "printf 'PNG 4x2 96x96' > \"$prev\"",
})
-- Formulas are typeset by this `tectonic`, which logs each run, and rasterized by this `pdftocairo`.
executable(bin, "tectonic", {
  "#!/bin/sh",
  "printf '%s\\n' \"$*\" >> '" .. bin .. "/typeset.log'",
  'prev=""',
  'for arg in "$@"; do',
  '  [ "$prev" = "--outdir" ] && outdir="$arg"',
  '  prev="$arg"',
  "done",
  'printf pdf > "$outdir/$(basename "$prev" .tex).pdf"',
})
executable(bin, "pdftocairo", { "#!/bin/sh", 'for arg in "$@"; do last="$arg"; done', 'printf png > "$last.png"' })
-- Charts are drawn by this `mmdc`, which logs each run.
executable(bin, "mmdc", {
  "#!/bin/sh",
  "printf '%s\\n' \"$*\" >> '" .. bin .. "/charts.log'",
  'prev=""',
  'for arg in "$@"; do',
  '  [ "$prev" = "-o" ] && out="$arg"',
  '  prev="$arg"',
  "done",
  'printf png > "$out"',
})
local path_env = vim.env.PATH ---@type string
vim.env.PATH = bin .. ":" .. path_env
t:defer(function()
  vim.env.PATH = path_env
end)

t:patch_table(package.loaded, "era.m.image.terminal", {
  request = function() end,
  size = function()
    return { width = 1000, height = 1000, columns = 100, rows = 50, cell_width = 10, cell_height = 20, scale = 1 }
  end,
})

local state = require("era.m.image.state")
local convert = require("era.m.image.convert")
t:patch_table(state.data, "tmpdir", t:tempdir())

---@param uri                           string
---@return era.m.image.Convert
local function conversion_of(uri)
  return convert.convert({ source = convert.source(uri) })
end

---@param conversion                    era.m.image.Convert
---@return nil
local function finish(conversion)
  conversion:run()
  t.wait_until(function()
    return conversion:done()
  end, 5000, "conversion")
end

t:test("data URIs are decoded the way browsers read them", function()
  -- "\251\255\191A" is "+/+/QQ==" in base64: here URL-safe, unpadded and broken across lines.
  local loose = conversion_of("data:image/png;base64,-_-_\nQQ")
  t.assert_eq("\251\255\191A", fs.read(loose.src), "loose base64")

  local svg = conversion_of("data:image/svg+xml;charset=utf-8;base64," .. vim.base64.encode("<svg/>"))
  t.assert_eq("<svg/>", fs.read(svg.src), "base64 after another parameter")
end)

t:test("an undecodable data URI fails its own conversion instead of raising", function()
  local ok, conversion = pcall(conversion_of, "data:image/png;base64,@@@")
  t.assert_true(ok, "conversion created")
  ---@cast conversion era.m.image.Convert

  finish(conversion)
  t.assert_true(conversion:error() ~= nil, "conversion failed")
end)

t:test("a step whose output an earlier step of the same run wrote does not run again", function()
  local file = t:tempdir() .. "/photo.jpg" ---@type string
  vim.fn.writefile({ "jpg" }, file)
  local conversion = conversion_of(file)
  t.assert_same(
    { "convert", "identify" },
    vim.tbl_map(function(step)
      return step.name
    end, conversion.steps),
    "steps"
  )

  finish(conversion)

  t.assert_nil(conversion:error(), "conversion error")
  t.assert_true(conversion.steps[1].proc ~= nil, "conversion ran")
  t.assert_nil(conversion.steps[2].proc, "identification already written")
  t.assert_same({ width = 4, height = 2 }, assert(conversion.meta.info).size, "identified size")
end)

t:test("a conversion step that hangs is stopped and frees its slot", function()
  t:patch_table(state.data, "convert_timeout", 300)
  local dir = t:tempdir() ---@type string
  local conversions = {} ---@type era.m.image.Convert[]
  -- Three hanging steps take every slot, so the last conversion can only run once they are stopped.
  for _, name in ipairs({ "slow1", "slow2", "slow3", "fast" }) do
    local file = dir .. "/" .. name .. ".png" ---@type string
    vim.fn.writefile({ "png" }, file)
    conversions[#conversions + 1] = conversion_of(file)
    conversions[#conversions]:run()
  end
  local fast = conversions[4]

  t.wait_until(function()
    return fast:done()
  end, 5000, "conversion behind the hanging ones")

  t.assert_nil(fast:error(), "conversion error")
  for i = 1, 3 do
    t.assert_true(conversions[i]:done(), "hanging conversion stopped")
    t.assert_true(tostring(conversions[i]:error()):find("timed out", 1, true) ~= nil, "timeout reported")
  end
end)

---The lines the fake executables logged to `name` in `bin`.
---@param name                          string
---@return string[]
local function logged(name)
  local log = bin .. "/" .. name ---@type string
  return vim.fn.filereadable(log) == 1 and vim.fn.readfile(log) or {}
end

---The arguments of each `magick` run after the first `skip` ones.
---@param skip                          integer
---@return string[]
local function magick_runs(skip)
  return vim.list_slice(logged("runs.log"), skip + 1)
end

-- PostScript, which ImageMagick would hand to Ghostscript if it went by the content.
local POSTSCRIPT = { "%!PS-Adobe-3.0", "showpage" } ---@type string[]

t:test("ImageMagick reads a source only as the format its extension names", function()
  local dir = t:tempdir() ---@type string
  -- A PNG is only identified, other formats are converted first: either way ImageMagick reads the source itself.
  for name, coder in pairs({ ["disguised.png"] = "PNG", ["photo.JPG"] = "JPEG" }) do
    vim.fn.writefile(POSTSCRIPT, dir .. "/" .. name)
    local skip = #magick_runs(0) ---@type integer

    finish(conversion_of(dir .. "/" .. name))

    local run = magick_runs(skip)[1] or "" ---@type string
    local input = run:match("(%S*/" .. vim.pesc(name) .. "%[0%])") ---@type string|nil
    t.assert_eq(coder .. ":", input and input:match("^%u+:"), name .. ": " .. run)
  end
end)

t:test("a source in a format ImageMagick is not named for fails before it runs", function()
  local dir = t:tempdir() ---@type string
  local skip = #magick_runs(0) ---@type integer
  for _, name in ipairs({ "figure.eps", "drawing.mvg", "logo" }) do
    vim.fn.writefile(POSTSCRIPT, dir .. "/" .. name)
    local conversion = conversion_of(dir .. "/" .. name)

    finish(conversion)

    local err = conversion:error() or "" ---@type string
    t.assert_true(err:find("Unsupported image format", 1, true) ~= nil, name .. ": " .. err)
  end
  t.assert_same({}, magick_runs(skip), "ImageMagick never ran")
end)

t:test("a data URI names the format of its decoded file, never a path", function()
  local conversion = conversion_of("data:image/../../../x;base64,QUJD")

  t.assert_eq(state.data.tmpdir, vim.fs.dirname(conversion.src), "decoded into the cache")
  t.assert_true(vim.fs.basename(conversion.src):match("^%x+%.%w*$") ~= nil, conversion.src)
end)

t:test("the cache is the account's own and keeps what a conversion used within a month", function()
  local dir = t:tempdir() ---@type string
  t:patch_table(state.data, "tmpdir", dir)
  vim.uv.fs_chmod(dir, tonumber("755", 8))
  local month_ago = os.time() - 40 * 24 * 3600 ---@type integer
  ---@param path                        string
  ---@return string
  local function aged(path)
    vim.fn.writefile({ "old" }, path)
    vim.uv.fs_utime(path, month_ago, month_ago)
    return path
  end
  local sources = t:tempdir() ---@type string
  vim.fn.writefile({ "png" }, sources .. "/photo.png")
  vim.fn.writefile({ "png" }, sources .. "/other.png")

  -- A session converts an image, and after a month of leaving its files alone uses them again.
  local first = assert(loadfile("lua/era/m/image/convert.lua"))()
  finish(first.convert({ source = first.source(sources .. "/photo.png") }))
  for name in vim.fs.dir(dir) do
    vim.uv.fs_utime(dir .. "/" .. name, month_ago, month_ago)
  end
  local reused = first.convert({ source = first.source(sources .. "/photo.png") })
  local stale = { aged(dir .. "/0123abcd-chart.png"), aged(dir .. "/4567cdef-content.math.tex") } ---@type string[]
  local foreign = aged(dir .. "/notes.txt") ---@type string

  -- The next session readies the cache with its first conversion.
  local second = assert(loadfile("lua/era/m/image/convert.lua"))()
  second.convert({ source = second.source(sources .. "/other.png") })

  t.assert_eq(tonumber("700", 8), vim.uv.fs_stat(dir).mode % 512, "permissions")
  for _, path in ipairs(stale) do
    t.assert_nil(vim.uv.fs_stat(path), "dropped: " .. vim.fs.basename(path))
  end
  t.assert_true(vim.uv.fs_stat(reused.marker) ~= nil, "a conversion used within the month is kept")
  t.assert_true(vim.uv.fs_stat(foreign) ~= nil, "a file the cache did not name is kept")
end)

t:test("a formula is typeset once, and each color only recolors it", function()
  local file = t:tempdir() .. "/0123456789abcdef-content.math.tex" ---@type string
  vim.fn.writefile({ "x" }, file)
  local source = convert.source(file)
  local typeset, skip = #logged("typeset.log"), #magick_runs(0)

  local blue = convert.convert({ source = source, color = "0078D4" })
  finish(blue)
  local pink = convert.convert({ source = source, color = "EB6F92" })
  finish(pink)
  finish(convert.convert({ source = source, color = "0078D4" }))

  t.assert_nil(pink:error(), "conversion error")
  t.assert_eq(typeset + 1, #logged("typeset.log"), "typeset once")
  local recolors = vim.tbl_filter(function(run)
    return run:find("-opaque black", 1, true) ~= nil
  end, magick_runs(skip))
  t.assert_eq(2, #recolors, "each color recolored once")
  t.assert_true(recolors[2]:find("-fill #EB6F92", 1, true) ~= nil, recolors[2])
  t.assert_true(blue.file ~= pink.file, "a file per color")
  for _, conversion in ipairs({ blue, pink }) do
    t.assert_true(vim.uv.fs_stat(conversion.file) ~= nil, "kept: " .. conversion.file)
  end
end)

---The position of the first event `match` accepts, or `math.huge`.
---@param events                        table[]
---@param match                         fun(event: table): boolean
---@return number
local function position(events, match)
  for i, event in ipairs(events) do
    if match(event) then
      return i
    end
  end
  return math.huge
end

t:test("a new theme color redraws a formula under a new id without typesetting it again", function()
  local Image = require("era.m.image.image")
  local events = {} ---@type table[]
  t:patch_table(package.loaded["era.m.image.terminal"], "request", function(opts)
    events[#events + 1] = opts
  end)
  t:defer(function()
    vim.api.nvim_set_hl(0, "m_img_math", {})
  end)
  vim.api.nvim_set_hl(0, "m_img_math", { fg = 0x0078D4 })
  local file = t:tempdir() .. "/fedcba9876543210-content.math.tex" ---@type string
  vim.fn.writefile({ "y" }, file)
  local img = Image.new(file)
  img:place({
    id = 931,
    update = function()
      events[#events + 1] = { shown = img.id }
    end,
  })
  t:defer(function()
    img:del()
  end)
  t.wait_until(function()
    return img.sent == true
  end, 5000, "formula sent")
  local old, typeset = img.id, #logged("typeset.log")

  vim.api.nvim_set_hl(0, "m_img_math", { fg = 0xEB6F92 })
  Image.recolor()
  t.wait_until(function()
    return img.sent == true and vim.endswith(img.file, ".EB6F92.tint.png")
  end, 5000, "formula recolored")

  t.assert_eq(typeset, #logged("typeset.log"), "not typeset again")
  t.assert_eq(img, Image.new(file), "the same image")
  t.assert_true(img.id ~= old, "a new id")
  -- The terminal drops the placements of an image sent anew under its id: the new colors go under the new one, the
  -- placement shows them, and only then the old colors go.
  local sent = position(events, function(event)
    return event.t == "f" and event.i == img.id
  end)
  local shown = position(events, function(event)
    return event.shown == img.id
  end)
  local released = position(events, function(event)
    return event.a == "d" and event.d == "I" and event.i == old
  end)
  t.assert_eq(vim.base64.encode(img.file), (events[sent] or {}).data, "in the new color")
  t.assert_true(sent < shown and shown < released, ("sent %s, shown %s, released %s"):format(sent, shown, released))
end)

t:test("a formula nothing shows is left alone by a theme change and takes the new color once shown", function()
  local Image = require("era.m.image.image")
  local transmitted = {} ---@type table[]
  t:patch_table(package.loaded["era.m.image.terminal"], "request", function(opts)
    if opts.t == "f" then
      transmitted[#transmitted + 1] = opts
    end
  end)
  t:defer(function()
    vim.api.nvim_set_hl(0, "m_img_math", {})
  end)
  vim.api.nvim_set_hl(0, "m_img_math", { fg = 0x0078D4 })
  local file = t:tempdir() .. "/0f1e2d3c4b5a6978-content.math.tex" ---@type string
  vim.fn.writefile({ "z" }, file)
  local img = Image.new(file)
  img:place({ id = 941, update = function() end })
  t:defer(function()
    img:del()
  end)
  t.wait_until(function()
    return img.sent == true
  end, 5000, "formula sent")
  img:del(941)

  vim.api.nvim_set_hl(0, "m_img_math", { fg = 0xEB6F92 })
  Image.recolor()

  t.assert_eq("0078D4", assert(img.convert).color, "not converted again")
  t.assert_eq(1, #transmitted, "not sent")
  img:place({ id = 942, update = function() end })
  t.wait_until(function()
    return img.sent == true
  end, 5000, "formula shown again")
  t.assert_true(vim.endswith(img.file, ".EB6F92.tint.png"), img.file)
  t.assert_eq(vim.base64.encode(img.file), transmitted[#transmitted].data, "sent in the new color")
end)

t:test("a formula in black ink alone takes the color", function()
  -- The ImageMagick installed, which reads such an image as grayscale.
  local previous = vim.env.PATH ---@type string
  t:defer(function()
    vim.env.PATH = previous
  end)
  vim.env.PATH = path_env
  if vim.fn.executable("magick") == 0 then
    t.skip("needs ImageMagick")
  end
  local tex_bin = t:tempdir() ---@type string
  local ink = tex_bin .. "/ink.png" ---@type string
  local drawn = vim
    .system({ "magick", "-size", "40x20", "xc:none", "-fill", "black", "-draw", "rectangle 5,5 30,15", "PNG32:" .. ink })
    :wait()
  t.assert_eq(0, drawn.code, drawn.stderr)
  vim.uv.fs_copyfile(bin .. "/tectonic", tex_bin .. "/tectonic")
  vim.fn.setfperm(tex_bin .. "/tectonic", "rwxr-xr-x")
  executable(
    tex_bin,
    "pdftocairo",
    { "#!/bin/sh", 'for arg in "$@"; do last="$arg"; done', "cp '" .. ink .. '\' "$last.png"' }
  )
  vim.env.PATH = tex_bin .. ":" .. path_env
  local file = t:tempdir() .. "/8899aabbccddeeff-content.math.tex" ---@type string
  vim.fn.writefile({ "ink" }, file)

  local conversion = convert.convert({ source = convert.source(file), color = "005FB8" })
  finish(conversion)

  t.assert_nil(conversion:error(), "conversion error")
  local histogram = vim
    .system({ "magick", conversion.file, "-depth", "8", "-format", "%c", "histogram:info:-" }, { text = true })
    :wait().stdout or "" ---@type string
  local colors = {} ---@type table<string, boolean>
  for rgb, alpha in histogram:gmatch("#(%x%x%x%x%x%x)(%x%x)") do
    if alpha ~= "00" then
      colors[rgb] = true
    end
  end
  t.assert_same({ ["005FB8"] = true }, colors, histogram)
end)

t:test("a chart is drawn once for each background, in the style of the one it was asked for", function()
  local background = vim.o.background ---@type string
  t:defer(function()
    vim.o.background = background
  end)
  local file = t:tempdir() .. "/0123456789abcdef-content.chart.mmd" ---@type string
  vim.fn.writefile({ "graph TD; A-->B" }, file)
  local source = convert.source(file)
  local drawn = #logged("charts.log") ---@type integer

  vim.o.background = "dark"
  local dark = convert.convert({ source = source })
  finish(dark)
  vim.o.background = "light"
  local light = convert.convert({ source = source })
  -- The background changes again before the chart is drawn.
  vim.o.background = "dark"
  finish(light)
  finish(convert.convert({ source = source }))

  t.assert_nil(light:error(), "conversion error")
  local runs = vim.list_slice(logged("charts.log"), drawn + 1) ---@type string[]
  t.assert_eq(2, #runs, "drawn once for each background")
  t.assert_true(runs[2]:find("-t neutral", 1, true) ~= nil, runs[2])
  t.assert_true(dark.file ~= light.file, "a file for each background")
  for _, conversion in ipairs({ dark, light }) do
    t.assert_true(vim.uv.fs_stat(conversion.file) ~= nil, "kept: " .. conversion.file)
  end
end)

t:test("a new background draws a chart again under a new id", function()
  local Image = require("era.m.image.image")
  local events = {} ---@type table[]
  t:patch_table(package.loaded["era.m.image.terminal"], "request", function(opts)
    events[#events + 1] = opts
  end)
  local background = vim.o.background ---@type string
  t:defer(function()
    vim.o.background = background
  end)
  vim.o.background = "dark"
  local file = t:tempdir() .. "/fedcba9876543210-content.chart.mmd" ---@type string
  vim.fn.writefile({ "graph LR; A-->B" }, file)
  local img = Image.new(file)
  img:place({ id = 951, update = function() end })
  t:defer(function()
    img:del()
  end)
  t.wait_until(function()
    return img.sent == true
  end, 5000, "chart sent")
  local old = img.id ---@type integer

  vim.o.background = "light"
  Image.recolor()
  t.wait_until(function()
    return img.sent == true and vim.endswith(img.file, ".light.png")
  end, 5000, "chart drawn again")

  t.assert_eq(img, Image.new(file), "the same image")
  t.assert_true(img.id ~= old, "a new id")
  local sent = position(events, function(event)
    return event.t == "f" and event.i == img.id
  end)
  local released = position(events, function(event)
    return event.a == "d" and event.d == "I" and event.i == old
  end)
  t.assert_eq(vim.base64.encode(img.file), (events[sent] or {}).data, "for the new background")
  t.assert_true(sent < released, ("sent %s, released %s"):format(sent, released))
end)

t:run()
