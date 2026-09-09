---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.m.git.encoding" ---@type string

local harness = require("__test__.support.harness")
local fixture = require("__test__.fixtures.era.m.git.encoding")
local staging = require("era.m.git.staging")
local t = harness.new("era.m.git.encoding")

for _, format in ipairs(fixture.formats) do
  t:test(format.name .. ": bytes match Neovim writing, including BOM and leading U+FEFF", function()
    t:patch_table(vim, "iconv", function()
      error("Unicode codecs must not use iconv")
    end)
    local names = { format.name, unpack(format.aliases) }
    local texts = { "", "\n", "one\ntwo", "A\0é中\n", "\239\187\191start\n" }
    if format.astral then
      texts[#texts + 1] = "🙂\n"
    end
    for _, text in ipairs(texts) do
      for _, bomb in ipairs({ false, true }) do
        for _, fileformat in ipairs({ "unix", "dos" }) do
          local eol = fileformat == "dos" and "\r\n" or "\n"
          local source = text:gsub("\n", eol)
          local expected = fixture.write(t, text, format.name, bomb, fileformat)
          for _, encoding in ipairs(names) do
            local document = staging.from_text(source, { encoding = encoding, bomb = bomb, default_eol = eol })
            local actual = assert(staging.encode(document))
            t.assert_eq(format.name, document.encoding, encoding .. " canonical name")
            t.assert_eq(fixture.hex(expected), fixture.hex(actual), encoding .. " native writer parity")
            local decoded = assert(staging.from_blob(expected, encoding, eol))
            t.assert_eq(fixture.hex(expected), fixture.hex(assert(staging.encode(decoded))), encoding .. " round-trip")
            t.assert_eq(bomb or text:sub(1, 3) == "\239\187\191", decoded.bomb, "decoded marker")
            if bomb or text:sub(1, 3) ~= "\239\187\191" then
              t.assert_eq(source, decoded.text, "decoded text")
            end
          end
        end
      end
    end
  end)
end

t:test("normalization preserves the legacy fallback and UTF-8 byte contract", function()
  for _, name in ipairs({ "", "utf8", "UTF_8" }) do
    t.assert_eq("utf-8", staging.normalize_encoding(name))
  end
  t.assert_eq("utf-8", staging.normalize_encoding(nil))
  t.assert_eq("shift_jis", staging.normalize_encoding("SHIFT_JIS"))
  t.assert_eq("\255_encoding", staging.normalize_encoding("\255_ENCODING"))
  local bytes = "\255\0\192\128"
  for _, bomb in ipairs({ false, true }) do
    local marked = bomb and ("\239\187\191" .. bytes) or bytes
    local document = assert(staging.from_blob(marked, "utf8"))
    t.assert_eq(bytes, document.text)
    t.assert_eq(bomb, document.bomb)
    t.assert_eq(marked, assert(staging.encode(document)))
  end
  local native = require("yoz").git.staging
  local text, bomb, decode_err = native.decode_unicode("x", "latin1")
  t.assert_nil(text, "legacy codec delegated")
  t.assert_false(bomb)
  t.assert_nil(decode_err, "not a Unicode failure")
  local encoded, encode_err = native.encode_unicode("x", "latin1", false)
  t.assert_nil(encoded, "legacy codec delegated")
  t.assert_nil(encode_err, "not a Unicode failure")
end)

t:test("malformed Unicode rejects the whole document without an iconv fallback", function()
  t:patch_table(vim, "iconv", function()
    error("invalid Unicode must not fall back to a lossy codec")
  end)
  for _, case in ipairs({
    { "utf-16", "\0A\0", "truncated" },
    { "utf-16le", "A\0\0\216", "surrogate" },
    { "utf-16", "\255\254a\0", "byte order" },
    { "utf-16le", "\254\255\0a", "byte order" },
    { "ucs-2", "\216\061\222\066", "surrogate" },
    { "ucs-2le", "\061\216\066\222", "surrogate" },
    { "ucs-4", "\0\0\0a\0", "truncated" },
    { "ucs-4le", "\0\0\017\0", "scalar" },
    { "ucs-4", "\255\254\0\0", "byte order" },
    { "ucs-4le", "\0\0\254\255", "byte order" },
  }) do
    local document, err = staging.from_blob(case[2], case[1])
    t.assert_nil(document, case[1] .. " decode refused")
    t.assert_true(err ~= nil and err:find(case[3], 1, true) ~= nil, tostring(err))
  end
  for _, format in ipairs(fixture.formats) do
    if format.name ~= "utf-8" then
      local bytes, err = staging.encode(staging.from_text("\255", { encoding = format.name }))
      t.assert_nil(bytes, "invalid UTF-8 source refused")
      t.assert_true(err ~= nil and err:find("invalid UTF-8", 1, true) ~= nil, tostring(err))
    end
    if not format.astral then
      local bytes, err = staging.encode(staging.from_text("🙂", { encoding = format.name, bomb = true }))
      t.assert_nil(bytes, "unrepresentable character refused")
      t.assert_true(err ~= nil and err:find("non-BMP", 1, true) ~= nil, tostring(err))
    end
  end
  local document = assert(staging.from_blob("\255\254\0\0", "utf-16le"))
  t.assert_eq("\0", document.text, "UTF-16 NUL must not be mistaken for a UTF-32 marker")
  t.assert_true(document.bomb)
  t.assert_eq("\255\254\0\0", assert(staging.encode(document)), "valid call after failures")
end)

t:run()
