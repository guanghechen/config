local harness = require("__test__.support.harness")
local diff = require("era.m.git.diff")
local native = require("yoz").git.word_diff
local reference = assert(loadfile("__test__/fixtures/era/m/git/diff_lua_reference.lua"))()
local t = harness.new()

---@param text                          string
---@return string
local function bytes_as_lines(text)
  local bytes = {}
  for index = 1, math.min(#text, 500) do
    bytes[index] = text:sub(index, index)
  end
  return table.concat(bytes, "\n")
end

t:test("native preparation preserves arbitrary bytes and the existing 500-byte cap", function()
  for _, text in ipairs({
    "",
    "a",
    "a\0\255\r\n",
    "中文🙂",
    string.rep("a", 499) .. "中文",
    string.rep("b", 1000),
  }) do
    local old, new = native.inputs(text, text:reverse())
    t.assert_eq(bytes_as_lines(text), old)
    t.assert_eq(bytes_as_lines(text:reverse()), new)
  end
end)

t:test("word ranges match the frozen Lua implementation on byte and boundary cases", function()
  for _, case in ipairs({
    { "", "" },
    { "", string.rep("x", 600) },
    { string.rep("x", 600), "" },
    { "same", "same" },
    { "fooBar", "fooBaz" },
    { "a b", "aXY b" },
    { "aXY b", "a b" },
    { "a  b", "A  B" },
    { "snake_case09", "snake_Case10" },
    { "\tA ; B.\0c", " A : B,\255c" },
    { "中文🙂 = '你好'", "中文🙃 = '您好'" },
    { "line\nbreak\r", "line\rbreak\n" },
    { string.rep("a", 499) .. "é", string.rep("a", 499) .. "中" },
    { string.rep("a", 500) .. "X", string.rep("a", 500) .. "Y" },
    { string.rep("a", 65536), string.rep("b", 65536) },
  }) do
    t.assert_same(reference.compute_word_diff(case[1], case[2]), diff.compute_word_diff(case[1], case[2]), "word diff")
  end
end)

t:test("seeded byte edits preserve the actual histogram output and final ranges", function()
  local seed = 1949
  ---@param limit                       integer
  ---@return integer
  local function random(limit)
    seed = (seed * 48271) % 2147483647
    return seed % limit + 1
  end
  local alphabet = { "a", "B", "0", "_", " ", "\t", ",", ";", ":", ".", "\255", "\0", "\n", "\r", "中", "🙂" }
  for case = 1, 2000 do
    local old = {}
    for _ = 1, random(80) do
      old[#old + 1] = alphabet[random(#alphabet)]
    end
    local new = vim.deepcopy(old)
    for _ = 1, random(5) do
      local position = random(#new + 1)
      if random(3) == 1 and #new > 0 then
        table.remove(new, math.min(position, #new))
      elseif random(2) == 1 then
        table.insert(new, position, alphabet[random(#alphabet)])
      else
        new[position] = alphabet[random(#alphabet)]
      end
    end
    local old_text, new_text = table.concat(old), table.concat(new)
    t.assert_same(
      reference.compute_word_diff(old_text, new_text),
      diff.compute_word_diff(old_text, new_text),
      "case " .. case
    )
  end
end)

t:test("identity and empty-side fast paths do not cross the native boundary", function()
  t:patch_table(native, "inputs", function()
    error("fast paths must not prepare diff inputs")
  end)
  for _, case in ipairs({ { "same", "same" }, { "", string.rep("a", 600) }, { string.rep("b", 600), "" } }) do
    t.assert_same(reference.compute_word_diff(case[1], case[2]), diff.compute_word_diff(case[1], case[2]), "fast path")
  end
end)

t:test("Neovim failure retains the old bounded fallback; empty raw data stays empty", function()
  local old, new = string.rep("a", 1000), string.rep("b", 700)
  for _, failure in ipairs({ false, "invalid", 17 }) do
    local restore = t:patch_table(vim.text, "diff", function()
      return failure
    end)
    t.assert_same(reference.compute_word_diff(old, new), diff.compute_word_diff(old, new), "non-table fallback")
    restore()
  end
  local restore = t:patch_table(vim.text, "diff", function()
    error("injected diff failure")
  end)
  t.assert_same(reference.compute_word_diff(old, new), diff.compute_word_diff(old, new), "throw fallback")
  local result = diff.compute_word_diff(old, new)
  t.assert_eq(500, result[1].old_end, "fallback does not expand beyond the cap")
  t.assert_eq(500, result[1].new_end)
  restore()
  t:patch_table(vim.text, "diff", function()
    return {}
  end)
  t.assert_same({}, diff.compute_word_diff(old, new), "successful empty diff")
end)

t:test("malformed raw coordinates fail without returning partial ranges", function()
  for _, value in ipairs({ -1, 1.5, math.huge, 0 / 0, "1" }) do
    t.assert_false(pcall(native.finish, "old", "new", { { 1, 1, 1, 1 }, { value, 1, 1, 1 } }), "invalid coordinate")
  end
  t.assert_false(pcall(native.finish, "old", "new", { { 0, 1, 1, 1 } }), "zero nonempty start")
  t.assert_false(pcall(native.finish, "old", "new", { { 1, 1, 1 } }), "truncated row")
  t.assert_same(reference.compute_word_diff("fooBar", "fooBaz"), diff.compute_word_diff("fooBar", "fooBaz"), "recovery")
end)

t:test("hunk pairing, unequal line counts and input ownership remain unchanged", function()
  for _, texts in ipairs({
    { "a\nb\nc\n", "A\nB\n" },
    { "a\nb\n", "A\nB\nC\n" },
    { "", "a\nb\n" },
    { "a\nb\n", "" },
  }) do
    local hunks =
      diff.run_diff(vim.split(texts[1], "\n", { plain = true }), vim.split(texts[2], "\n", { plain = true }))
    local saved = vim.deepcopy(hunks)
    for _, hunk in ipairs(hunks) do
      t.assert_same(reference.compute_hunk_word_diff(hunk), diff.compute_hunk_word_diff(hunk), "paired lines")
    end
    t.assert_same(saved, hunks, "input unchanged")
  end
end)

t:test("compute_word_diff: native byte diff preserves byte-column ranges", function()
  local changes = diff.compute_word_diff("fooBar", "fooBaz")
  t.assert_eq(1, #changes, "change count")
  t.assert_eq(4, changes[1].old_start, "old start")
  t.assert_eq(6, changes[1].old_end, "old end")
  t.assert_eq(4, changes[1].new_start, "new start")
  t.assert_eq(6, changes[1].new_end, "new end")
end)

t:test("compute_hunk_word_diff: large hunks produce one change per line", function()
  local old_line = string.rep("a", 500) ---@type string
  local new_line = string.rep("b", 500) ---@type string
  ---@diagnostic disable-next-line: missing-fields
  local hunk = { type = "change", removed = { lines = {} }, added = { lines = {} } } ---@type era.m.git.Hunk
  for index = 1, 200 do
    hunk.removed.lines[index] = old_line
    hunk.added.lines[index] = new_line
  end

  local changes = diff.compute_hunk_word_diff(hunk)
  t.assert_eq(200, #changes, "line changes")
end)

t:run()
