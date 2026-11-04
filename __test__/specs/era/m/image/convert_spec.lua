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
-- writes the image after `-write` and its identification to the last argument.
local bin = t:tempdir() ---@type string
vim.fn.writefile({
  "#!/bin/sh",
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

t:run()
