local harness = require("__test__.support.harness")
local runtime = require("__test__.support.cmp.runtime")
local fixture = require("__test__.support.cmp.fixture")
runtime.setup()
local t = harness.new()

---@return string[]
local function completed_words()
  local words = {}
  require("era.keystroke.cmp.source.buffer").complete(runtime.context(""), function(response)
    for _, item in ipairs(response.items) do
      words[#words + 1] = item.raw.label
    end
  end)
  table.sort(words)
  return words
end

---@param lines                         string[]
---@return string[]
local function scanned_words(lines)
  local pattern = vim.regex([[\k\{3,}]])
  local words, seen = {}, {}
  for _, line in ipairs(lines) do
    local offset = 0
    while offset < #line do
      local left, right = pattern:match_str(line:sub(offset + 1))
      if left == nil then
        break
      end
      local word = line:sub(offset + left + 1, offset + right)
      if not seen[word] then
        words[#words + 1] = word
        seen[word] = true
      end
      offset = offset + right
    end
  end
  table.sort(words)
  return words
end

t:test("buffer limits count eligible buffers and retain the current buffer in tab order", function()
  local entries = {}
  local nofile_bufnr = fixture.buffer(t, { "ignored_nofile" })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = nofile_bufnr })
  entries[#entries + 1] = { bufnr = nofile_bufnr }
  entries[#entries + 1] = { bufnr = fixture.buffer(t, { "ignored_large" .. string.rep(" ", 131072) }) }
  for index = 1, 9 do
    entries[#entries + 1] = { bufnr = fixture.buffer(t, { "candidate_" .. index }) }
  end
  local bufnr = fixture.buffer(t, { "current_candidate" })
  entries[#entries + 1] = { bufnr = bufnr }
  entries[#entries + 1] = { bufnr = fixture.buffer(t, { "beyond_limit" }) }
  vim.api.nvim_set_current_buf(bufnr)
  t:patch_table(dot.tab, "resolve", function()
    return { bufs = entries }
  end)
  local words = completed_words()
  t.assert_eq(10, #words, "ten eligible buffers")
  t.assert_true(vim.list_contains(words, "current_candidate"), "current buffer is the tenth eligible entry")
  for _, word in ipairs({ "ignored_nofile", "ignored_large", "beyond_limit" }) do
    t.assert_eq(false, vim.list_contains(words, word), word .. " is excluded")
  end
end)

t:test("buffer size budget skips oversized entries and admits later small buffers", function()
  local entries = {}
  for _, entry in ipairs({
    { label = "first", size = 120000 },
    { label = "second", size = 120000 },
    { label = "third", size = 120000 },
    { label = "fourth", size = 120000 },
    { label = "over_budget", size = 25000 },
    { label = "tail", size = 100 },
  }) do
    local bufnr = fixture.buffer(t, { entry.label .. string.rep(" ", entry.size - #entry.label - 1) })
    entries[#entries + 1] = { bufnr = bufnr }
  end
  t:patch_table(dot.tab, "resolve", function()
    return { bufs = entries }
  end)
  t.assert_eq("first,fourth,second,tail,third", table.concat(completed_words(), ","), "500000 byte budget")
end)

t:test("buffer tokenization preserves Unicode and deduplicates words", function()
  fixture.buffer(t, { "alpha beta alpha", "中文变量 value_123" })
  local words = completed_words()
  t.assert_true(vim.list_contains(words, "中文变量"), "Unicode word")
  t.assert_eq(4, #words, "unique words")
end)

t:test("buffer words exclude malformed UTF-8 without discarding valid words on the same line", function()
  local bufnr = fixture.buffer(t, { "\255broken alpha 中文变量" })
  t.assert_eq("alpha,中文变量", table.concat(completed_words(), ","), "invalid token excluded")
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "repaired alpha 中文变量" })
  t.assert_eq("alpha,repaired,中文变量", table.concat(completed_words(), ","), "repaired tokens rejoin the cache")
end)

t:test("ASCII tokenization agrees with Vim keyword matching and falls back for custom options", function()
  local lines = { "foo-bar value_123 a ab abc 123 $foo", "abc 中文变量 éclair", "before\0after" }
  local bufnr = fixture.buffer(t, lines)
  for _, keyword in ipairs({ "@,48-57,_,192-255", "@,48-57,_,192-255,-", "@,_" }) do
    vim.api.nvim_set_option_value("iskeyword", keyword, { buf = bufnr })
    local expected = scanned_words(lines)
    local actual = completed_words()
    t.assert_eq(table.concat(expected, "\n"), table.concat(actual, "\n"), keyword .. " token boundaries")
  end
end)

t:test("buffer cache applies batched line insertions and deletions without losing duplicate words", function()
  local bufnr = fixture.buffer(t, { "" })
  ---@return string
  local function labels()
    return table.concat(completed_words(), ",")
  end
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "alpha shared", "beta shared", "gamma" })
  t.assert_eq("alpha,beta,gamma,shared", labels(), "initial words")
  vim.api.nvim_buf_set_lines(bufnr, 1, 2, false, { "delta shared", "added_word" })
  vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, {})
  vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "tail_word shared" })
  t.assert_eq("added_word,delta,gamma,shared,tail_word", labels(), "batched splices")
  vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, {})
  t.assert_eq("added_word,gamma,shared,tail_word", labels(), "one shared occurrence remains")
  vim.api.nvim_buf_set_lines(bufnr, -2, -1, false, {})
  t.assert_eq("added_word,gamma", labels(), "last shared occurrence removed")
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "foo-bar baz", "" })
  t.assert_eq("bar,baz,foo", labels(), "default keyword option")
  vim.api.nvim_set_option_value("iskeyword", "@,48-57,_,192-255,-", { buf = bufnr })
  t.assert_eq("baz,foo-bar", labels(), "option changes invalidate cached tokens")
  for index = 1, 150 do
    vim.api.nvim_buf_set_lines(bufnr, 1, 2, false, { "latest_" .. index })
  end
  t.assert_eq("baz,foo-bar,latest_150", labels(), "bounded edit log rebuilds from final text")
  for step = 1, 150 do
    local size = vim.api.nvim_buf_line_count(bufnr)
    local first = (step * 17) % (size + 1)
    local last = math.min(size, first + step % 3)
    local replacement = step % 4 == 0 and {} or { "word_" .. step .. " shared", "shared foo-bar" }
    vim.api.nvim_buf_set_lines(bufnr, first, last, false, replacement)
    if step % 5 == 0 then
      local expected = scanned_words(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
      t.assert_eq(table.concat(expected, ","), labels(), "full-rescan oracle after edit " .. step)
    end
  end
end)

t:test("sparse buffer caches survive empty-row edits, undo and redo", function()
  local bufnr = fixture.buffer(t, { "", "alpha", "", "", "shared", "" })
  t.assert_eq("alpha,shared", table.concat(completed_words(), ","))
  t.assert_eq("alpha,shared", table.concat(completed_words(), ","), "unchanged cache")
  vim.cmd("let &l:undolevels = &l:undolevels")
  vim.api.nvim_buf_set_lines(bufnr, 2, 4, false, { "beta shared", "", "" })
  t.assert_eq("alpha,beta,shared", table.concat(completed_words(), ","), "formerly empty rows gain words")
  vim.cmd.undo()
  t.assert_eq("alpha,shared", table.concat(completed_words(), ","), "undo restores empty rows")
  vim.cmd.redo()
  t.assert_eq("alpha,beta,shared", table.concat(completed_words(), ","), "redo restores word counts")
  vim.api.nvim_buf_set_lines(bufnr, 1, 3, false, { "", "" })
  t.assert_eq("shared", table.concat(completed_words(), ","), "another row still owns the shared word")
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "", "", "" })
  t.assert_eq(0, #completed_words(), "all empty rows release old words")
  t.assert_eq(0, #completed_words(), "empty cache remains reusable")
  vim.api.nvim_buf_set_lines(bufnr, 1, 2, false, { "new_word" })
  t.assert_eq("new_word", table.concat(completed_words(), ","), "editing one empty row keeps the others empty")
end)

t:test("buffer reload and detach discard even an unchanged sparse cache", function()
  local path = t:tempdir() .. "/sparse.txt"
  vim.fn.writefile({ "", "alpha", "" }, path)
  local bufnr = fixture.buffer(t, { "", "alpha", "" })
  vim.api.nvim_buf_set_name(bufnr, path)
  t.assert_eq("alpha", table.concat(completed_words(), ","))
  t.assert_eq("alpha", table.concat(completed_words(), ","), "warm sparse cache")
  vim.fn.writefile({ "", "beta", "", "" }, path)
  vim.cmd.edit({ bang = true })
  t.assert_eq("beta", table.concat(completed_words(), ","), "same buffer reloads disk words")
  t.assert_eq("beta", table.concat(completed_words(), ","))
  vim.api.nvim_buf_delete(bufnr, { unload = true })
  vim.fn.writefile({ "", "gamma", "" }, path)
  vim.fn.bufload(bufnr)
  vim.api.nvim_set_current_buf(bufnr)
  t.assert_eq("gamma", table.concat(completed_words(), ","), "detached buffer rebuilds when loaded again")
  vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "delta" })
  t.assert_eq("delta,gamma", table.concat(completed_words(), ","), "reloaded buffer keeps its new listener")
end)

t:run()
