local bootstrap = require("__test__.support.bootstrap")
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

-- Conversions run this `magick`, which hangs on any file whose name says so. Like the real one, a conversion
-- writes the image after `-write` and its identification to the last argument. Each run logs its arguments.
local bin = t:tempdir() ---@type string
vim.fn.writefile({
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
  '  [ "$prev" = "-write" ] && printf png > "$arg"',
  '  prev="$arg"',
  "done",
  "printf 'PNG 4x2 96x96' > \"$prev\"",
}, bin .. "/magick")
vim.fn.setfperm(bin .. "/magick", "rwxr-xr-x")
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

---@param path                          string
---@return string
local function read(path)
  local fd = assert(io.open(path, "rb"))
  local content = fd:read("*a") ---@type string
  fd:close()
  return content
end

t:test("data URIs are decoded the way browsers read them", function()
  -- "\251\255\191A" is "+/+/QQ==" in base64: here URL-safe, unpadded and broken across lines.
  local loose = conversion_of("data:image/png;base64,-_-_\nQQ")
  t.assert_eq("\251\255\191A", read(loose.src), "loose base64")

  local svg = conversion_of("data:image/svg+xml;charset=utf-8;base64," .. vim.base64.encode("<svg/>"))
  t.assert_eq("<svg/>", read(svg.src), "base64 after another parameter")
end)

t:test("an undecodable data URI fails its own conversion instead of raising", function()
  local ok, conversion = pcall(conversion_of, "data:image/png;base64,@@@")
  t.assert_true(ok, "conversion created")
  ---@cast conversion era.m.image.Convert

  conversion:run()
  t.wait_until(function()
    return conversion:done()
  end, 5000, "conversion")
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

  conversion:run()
  t.wait_until(function()
    return conversion:done()
  end, 5000, "conversion")

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

---The arguments of each `magick` run after the first `skip` ones.
---@param skip                          integer
---@return string[]
local function magick_runs(skip)
  local log = bin .. "/runs.log" ---@type string
  return vim.list_slice(vim.fn.filereadable(log) == 1 and vim.fn.readfile(log) or {}, skip + 1)
end

---@param conversion                    era.m.image.Convert
---@return nil
local function finish(conversion)
  conversion:run()
  t.wait_until(function()
    return conversion:done()
  end, 5000, "conversion")
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

t:run()
