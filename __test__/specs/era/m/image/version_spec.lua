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
    timer = require("stl.timer"),
  },
})

-- Identification runs this `magick`, so the suite needs no ImageMagick.
local bin = t:tempdir() ---@type string
vim.fn.writefile({ "#!/bin/sh", "echo 'PNG 4x2 96x96'" }, bin .. "/magick")
vim.fn.setfperm(bin .. "/magick", "rwxr-xr-x")
local path_env = vim.env.PATH ---@type string
vim.env.PATH = bin .. ":" .. path_env
t:defer(function()
  vim.env.PATH = path_env
end)

local requests = {} ---@type table[]
t:patch_table(package.loaded, "era.m.image.terminal", {
  request = function(opts)
    requests[#requests + 1] = opts
  end,
  size = function()
    return { width = 1000, height = 1000, columns = 100, rows = 50, cell_width = 10, cell_height = 20, scale = 1 }
  end,
})

local state = require("era.m.image.state")
t:patch_table(state.data, "tmpdir", t:tempdir())

---@param n                             integer
---@return string
local function u32(n)
  return string.char(math.floor(n / 16777216) % 256, math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256)
end

---Writes a PNG header; `padding` changes the file size so that a rewrite is always a new version.
---@param path                          string
---@param width                         integer
---@param height                        integer
---@param padding                       ?integer
---@return nil
local function write_png(path, width, height, padding)
  local fd = assert(io.open(path, "wb"))
  fd:write("\137PNG\r\n\26\n" .. u32(13) .. "IHDR" .. u32(width) .. u32(height) .. string.rep("\0", padding or 0))
  fd:close()
end

---@param bufnr                         integer
---@param ns                            integer
---@return boolean
local function has_placeholder(bufnr, ns)
  local placeholder = vim.fn.nr2char(0x10EEEE) ---@type string
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })) do
    for _, chunk in ipairs(mark[4].virt_text or {}) do
      if chunk[1]:find(placeholder, 1, true) then
        return true
      end
    end
  end
  return false
end

t:test("a rewritten source is converted under a new name", function()
  local convert = require("era.m.image.convert")
  local file = t:tempdir() .. "/a.png" ---@type string
  write_png(file, 4, 2)
  local before = convert.source(file)
  write_png(file, 4, 2, 8)
  local after = convert.source(file)

  t.assert_eq(before.id, after.id, "source")
  t.assert_true(before.version ~= after.version, "version")
  t.assert_true(convert.convert({ source = before }).prefix ~= convert.convert({ source = after }).prefix, "name")
end)

t:test("conversion outputs are reused only after a run completed", function()
  local convert = require("era.m.image.convert")
  local file = t:tempdir() .. "/b.png" ---@type string
  write_png(file, 4, 2)
  local source = convert.source(file)
  local first = convert.convert({ source = source })
  local identify = first.steps[#first.steps]
  -- An interrupted run left its output behind without the completion marker.
  vim.fn.writefile({ "partial" }, identify.file)
  t.assert_false(identify.done, "partial output")

  first:run()
  t.wait_until(function()
    return first:done()
  end, 5000, "conversion")

  t.assert_nil(first:error(), "conversion error")
  t.assert_same({ width = 4, height = 2 }, assert(first.meta.info).size, "identified size")
  t.assert_true(convert.convert({ source = source }).steps[1].done, "completed output")
end)

t:test("a replaced version releases its terminal data and outputs once nothing shows it", function()
  local Image = require("era.m.image.image")
  local file = t:tempdir() .. "/c.png" ---@type string
  write_png(file, 4, 2)
  local old = Image.new(file)
  t.wait_until(function()
    return old.sent == true
  end, 5000, "first version sent")
  t.assert_eq(old, Image.new(file), "unchanged source")
  local outputs = { assert(old.convert).marker, assert(old.convert).steps[1].file } ---@type string[]
  old:place({ id = 901, update = function() end })

  write_png(file, 8, 3, 8)
  local new = Image.new(file)
  t.wait_until(function()
    return assert(new.convert):done()
  end, 5000, "second version converted")
  t.assert_true(new ~= old and old.retired == true, "replaced version")
  t.assert_true(vim.uv.fs_stat(outputs[1]) ~= nil, "outputs kept while shown")

  old:del(901)

  local released = vim.tbl_filter(function(request)
    return vim.deep_equal(request, { a = "d", d = "I", i = old.id })
  end, requests)
  t.assert_eq(1, #released, "terminal data released")
  for _, output in ipairs(outputs) do
    t.assert_nil(vim.uv.fs_stat(output), "output removed: " .. output)
  end
  t.assert_true(vim.uv.fs_stat(file) ~= nil, "source kept")
end)

t:test("the terminal lets go of an image no placement shows, which is sent again once one does", function()
  local Image = require("era.m.image.image")
  local file = t:tempdir() .. "/g.png" ---@type string
  write_png(file, 4, 2)
  local img = Image.new(file)
  t.wait_until(function()
    return img.sent == true
  end, 5000, "image sent")
  img:place({ id = 921, update = function() end })
  local before = #requests ---@type integer

  img:del(921)

  t.assert_true(
    vim.tbl_contains(vim.list_slice(requests, before + 1), function(request)
      return vim.deep_equal(request, { a = "d", d = "I", i = img.id })
    end, { predicate = true }),
    "image data released"
  )
  t.assert_eq(img, Image.new(file), "still the current version")
  t.assert_true(vim.uv.fs_stat(assert(img.convert).marker) ~= nil, "conversion kept")
  img:place({ id = 922, update = function() end })
  t.assert_true(img.sent, "sent again")
end)

t:test("a placement shows an image whose source appears later", function()
  local Placement = require("era.m.image.placement")
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  vim.api.nvim_win_set_buf(0, bufnr)
  local file = t:tempdir() .. "/later.png" ---@type string
  local placement = Placement.new(bufnr, file, { inline = true, pos = { 1, 0 }, range = { 1, 0, 1, 0 } })
  t:defer(function()
    placement:close()
  end)
  local missing = placement.img
  t.assert_true(missing:failed(), "missing source")

  write_png(file, 4, 2)
  Placement.update(placement)
  t.assert_true(placement.img ~= missing, "follows the new file")
  t.wait_until(function()
    return placement.img.sent == true
  end, 5000, "converted")
  Placement.update(placement)

  t.assert_true(has_placeholder(bufnr, Placement.ns), "rendered")
end)

t:test("a viewer follows its rewritten source and stays unmodified", function()
  local Placement = require("era.m.image.placement")
  local bufnr = vim.api.nvim_create_buf(false, false) ---@type integer
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  vim.api.nvim_win_set_buf(0, bufnr)
  local file = t:tempdir() .. "/viewer.png" ---@type string
  write_png(file, 4, 2)
  local placement = Placement.new(bufnr, file, { conceal = true })
  t:defer(function()
    placement:close()
  end)
  t.wait_until(function()
    return placement.img.sent == true
  end, 5000, "first version")
  local first = placement.img

  write_png(file, 8, 3, 8)
  Placement.update(placement)
  t.assert_true(placement.img ~= first, "follows the rewritten file")
  t.wait_until(function()
    return placement.img.sent == true
  end, 5000, "second version")
  Placement.update(placement)

  t.assert_false(vim.api.nvim_get_option_value("modified", { buf = bufnr }), "viewer unmodified")
  t.assert_true(has_placeholder(bufnr, Placement.ns), "rendered")
end)

t:test("image ids are random, unique and fit a 24-bit color", function()
  local Image = require("era.m.image.image")
  local dir = t:tempdir() ---@type string
  local ids = {} ---@type table<integer, boolean>
  local consecutive = 0 ---@type integer
  local previous = nil ---@type integer|nil
  for i = 1, 50 do
    local file = ("%s/id%d.png"):format(dir, i) ---@type string
    write_png(file, 4, 2)
    local id = Image.new(file).id
    t.assert_true(id > 0 and id <= 0xFFFFFF, "24-bit id")
    t.assert_nil(ids[id], "unique id")
    ids[id] = true
    consecutive = consecutive + ((previous and id == previous + 1) and 1 or 0)
    previous = id
  end
  t.assert_true(consecutive < 5, "ids do not count up")
end)

t:test("a placement leaves by its own id and the image is sent again after a resend", function()
  local Image = require("era.m.image.image")
  local file = t:tempdir() .. "/f.png" ---@type string
  write_png(file, 4, 2)
  local img = Image.new(file)
  t.wait_until(function()
    return img.sent == true
  end, 5000, "image sent")
  img:place({ id = 911, update = function() end })
  img:place({ id = 912, update = function() end })

  img:del(911)
  t.assert_true(
    vim.tbl_contains(requests, function(request)
      return vim.deep_equal(request, { a = "d", d = "i", i = img.id, p = 911 })
    end, { predicate = true }),
    "placement deleted by its id"
  )

  Image.resend()
  t.assert_false(img.sent, "sent again on the next placement")
  local before = #requests ---@type integer
  img:place({ id = 913, update = function() end })
  local transmitted = vim.tbl_filter(function(request)
    return request.t == "f" and request.i == img.id
  end, vim.list_slice(requests, before + 1))
  t.assert_eq(1, #transmitted, "image transmitted again")
end)

t:test("an extension in capitals is supported", function()
  t.assert_true(state.is_support_file("/photos/IMG_0001.HEIC"), "HEIC")
  t.assert_true(state.is_support_file("/shots/SHOT.PNG"), "PNG")
  t.assert_false(state.is_support_file("/notes/README.MD"), "markdown")
end)

t:test("the pixel size of a PNG rewritten in place is read again", function()
  local file = t:tempdir() .. "/d.png" ---@type string
  write_png(file, 4, 2)
  t.assert_same({ width = 4, height = 2 }, state.dim(file), "first size")
  write_png(file, 8, 3, 8)
  t.assert_same({ width = 8, height = 3 }, state.dim(file), "rewritten size")
end)

t:test("discarding a conversion deletes only its own files in the cache", function()
  local convert = require("era.m.image.convert")
  local dir = t:tempdir() ---@type string
  local file = dir .. "/e.png" ---@type string
  local outside = dir .. "/outside.info" ---@type string
  write_png(file, 4, 2)
  vim.fn.writefile({ "keep" }, outside)
  local conversion = convert.convert({ source = convert.source(file) })
  conversion:run()
  t.wait_until(function()
    return conversion:done()
  end, 5000, "conversion")
  local output = conversion.steps[1].file ---@type string
  conversion.steps[2] = vim.tbl_extend("force", conversion.steps[1], { file = outside })

  conversion:discard()

  t.assert_nil(vim.uv.fs_stat(output), "own output removed")
  t.assert_nil(vim.uv.fs_stat(conversion.marker), "marker removed")
  t.assert_true(vim.uv.fs_stat(outside) ~= nil, "file outside the cache kept")
  t.assert_true(vim.uv.fs_stat(file) ~= nil, "source kept")
end)

t:run()
