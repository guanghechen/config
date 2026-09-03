---@diagnostic disable: undefined-global

local harness = require("__test__.harness")

local t = harness.new("era.m.cmp.source")

_G.yoz = require("yoz")
_G.stl = require("stl")

local initial_cwd = assert(vim.uv.cwd()) ---@type string
local cwd = initial_cwd ---@type string
---@diagnostic disable-next-line: missing-fields
_G.dot = {
  var = { N_CMP_DOCUMENTATION = "dot_cmp_documentation" },
  path = {
    cwd = function()
      return cwd
    end,
    dirname = function(filepath)
      return vim.fs.dirname(filepath)
    end,
    join = function(from, to)
      return vim.fs.joinpath(from, to)
    end,
    normalize = function(filepath, keep_trailing_slash)
      return yoz.path.normalize(filepath, keep_trailing_slash ~= false, "/")
    end,
    relative = function(from, to, separator)
      return yoz.path.relative(from, to, false, separator or "/")
    end,
    resolve = function(from, to)
      return vim.fs.normalize(vim.fs.joinpath(from, to))
    end,
    workspace = function()
      return cwd
    end,
  },
  tab = {
    resolve = function()
      return nil
    end,
  },
}

local Source = require("era.m.cmp.source")

local function complete(line, filetype, cursor_col, filepath, unnamed)
  local bufnr = vim.api.nvim_create_buf(false, true)
  if not unnamed then
    vim.api.nvim_buf_set_name(bufnr, filepath or vim.fn.tempname() .. "." .. filetype)
  end
  vim.api.nvim_set_option_value("filetype", filetype, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { line })
  local result
  Source.complete({
    textDocument = { uri = vim.uri_from_bufnr(bufnr) },
    position = { line = 0, character = cursor_col or #line },
  }, {}, function(value)
    result = value
  end, bufnr)
  t.wait_until(function()
    return result ~= nil
  end, 1000, "completion result")
  vim.api.nvim_buf_delete(bufnr, { force = true })
  return result
end

t:test("markdown completion includes slash commands", function()
  local result = complete("/com", "markdown")
  t.assert_true(result.isIncomplete, "incomplete response")
  t.assert_true(
    vim.iter(result.items):any(function(item)
      return item.label == "/commit"
    end),
    "commit command"
  )
end)

t:test("local sources replace the token suffix", function()
  local result = complete("future", "lua", 3)
  local item = assert(vim.iter(result.items):find(function(candidate)
    return candidate.label == "future" and candidate.data.era_cmp.source == "dict"
  end))
  t.assert_eq(6, item.textEdit.range["end"].character, "dictionary suffix end")

  local root = vim.fn.tempname()
  vim.fn.mkdir(root, "p")
  local filepath = vim.fs.joinpath(root, "sample.lua")
  local file = assert(io.open(filepath, "wb"))
  file:write("return true\n")
  file:close()
  cwd = root
  local path_result = complete("sample.old", stl.filetype.UX_PICKER_FINDER, 3)
  local path_item = assert(vim.iter(path_result.items):find(function(candidate)
    return candidate.label == "sample.lua"
  end))
  t.assert_eq(#"sample.old", path_item.textEdit.range["end"].character, "path suffix end")
  vim.fn.delete(root, "rf")
  cwd = initial_cwd
end)

t:test("code completion includes dictionary entries", function()
  local result = complete("futu", "lua")
  t.assert_true(
    vim.iter(result.items):any(function(item)
      return item.data.era_cmp.source == "dict"
    end),
    "dictionary source"
  )
end)

t:test("at paths use the current workspace", function()
  local root = vim.fn.tempname()
  vim.fn.mkdir(root, "p")
  local filepath = vim.fs.joinpath(root, "sample.lua")
  local file = assert(io.open(filepath, "wb"))
  file:write("return true\n")
  file:close()
  cwd = root

  local result = complete("@sam", "lua")
  t.assert_true(
    vim.iter(result.items):any(function(item)
      return item.label == "sample.lua" and item.data.era_cmp.source == "path_at"
    end),
    "workspace path"
  )

  local finder = complete("sam", stl.filetype.UX_PICKER_FINDER)
  t.assert_true(
    vim.iter(finder.items):any(function(item)
      return item.label == "sample.lua" and item.data.era_cmp.source == "path"
    end),
    "finder plain path"
  )
  local unnamed_finder = complete("sam", stl.filetype.UX_PICKER_FINDER, nil, nil, true)
  t.assert_true(
    vim.iter(unnamed_finder.items):any(function(item)
      return item.label == "sample.lua" and item.data.era_cmp.source == "path"
    end),
    "unnamed finder path"
  )

  vim.fn.delete(root, "rf")
  cwd = initial_cwd
end)

t:test("at paths require an explicit token boundary", function()
  local Path = require("era.m.cmp.source.path")
  local scans = {} ---@type string[]
  t:patch_table(vim.uv, "fs_scandir", function(dirname)
    scans[#scans + 1] = dirname
    return nil, "unexpected scan"
  end)

  for _, line in ipairs({ "user@exa", "identifier@path", "https://user@host" }) do
    local result
    Path.complete_at({
      bufnr = 0,
      row = 0,
      col = #line,
      line = line,
      filetype = "markdown",
      start_col = 0,
      end_col = #line,
      keyword = "",
    }, function(items)
      result = items
    end)
    t.assert_eq(0, #assert(result), "at path items: " .. line)
  end
  t.assert_eq(0, #scans, "filesystem scans")
end)

t:test("ordinary paths use the request buffer directory", function()
  local root = vim.fn.tempname()
  local buffer_dir = vim.fs.joinpath(root, "nested")
  vim.fn.mkdir(buffer_dir, "p")
  local filepath = vim.fs.joinpath(buffer_dir, "sample.lua")
  local file = assert(io.open(filepath, "wb"))
  file:write("return true\n")
  file:close()
  cwd = root

  for _, line in ipairs({ '"sam', '"./sam' }) do
    local result = complete(line, "lua", nil, vim.fs.joinpath(buffer_dir, "main.lua"))
    t.assert_true(
      vim.iter(result.items):any(function(item)
        return item.label == "sample.lua" and item.data.era_cmp.source == "path"
      end),
      "buffer-relative path: " .. line
    )
  end

  vim.fn.delete(root, "rf")
  cwd = initial_cwd
end)

t:test("path frecency identity is scoped to the resolved directory", function()
  local roots = { vim.fn.tempname(), vim.fn.tempname() }
  local keys = {} ---@type string[]
  for index, root in ipairs(roots) do
    vim.fn.mkdir(root, "p")
    vim.fn.writefile({ "sample" }, vim.fs.joinpath(root, "sample.lua"))
    cwd = root
    local result = complete("sam", stl.filetype.UX_PICKER_FINDER)
    local item = assert(vim.iter(result.items):find(function(candidate)
      return candidate.label == "sample.lua"
    end))
    keys[index] = item.data.era_cmp.usage_key
  end

  t.assert_false(keys[1] == keys[2], "directory-scoped path usage")
  for _, root in ipairs(roots) do
    vim.fn.delete(root, "rf")
  end
  cwd = initial_cwd
end)

t:test("quoted ordinary paths preserve spaces while traversing directories", function()
  local root = vim.fn.tempname()
  local buffer_dir = vim.fs.joinpath(root, "nested")
  local spaced_dir = vim.fs.joinpath(buffer_dir, "my dir")
  vim.fn.mkdir(spaced_dir, "p")
  local filepath = vim.fs.joinpath(spaced_dir, "child.lua")
  local file = assert(io.open(filepath, "wb"))
  file:write("return true\n")
  file:close()
  cwd = root

  local result = complete('"my dir/ch', "lua", nil, vim.fs.joinpath(buffer_dir, "main.lua"))
  t.assert_true(
    vim.iter(result.items):any(function(item)
      return item.label == "child.lua" and item.data.era_cmp.source == "path"
    end),
    "space-containing quoted path"
  )
  for _, spec in ipairs({
    { line = 'r"my dir/ch', filetype = "python" },
    { line = "f'my dir/ch", filetype = "python" },
    { line = 'b"my dir/ch', filetype = "python" },
    { line = 't"my dir/ch', filetype = "python" },
    { line = 'tr"my dir/ch', filetype = "python" },
    { line = 'rt"my dir/ch', filetype = "python" },
    { line = 'u8"my dir/ch', filetype = "cpp" },
    { line = 'L"my dir/ch', filetype = "cpp" },
    { line = 'u8R"my dir/ch', filetype = "cpp" },
    { line = 'cr"my dir/ch', filetype = "rust" },
  }) do
    local prefixed = complete(spec.line, spec.filetype, nil, vim.fs.joinpath(buffer_dir, "main." .. spec.filetype))
    t.assert_true(
      vim.iter(prefixed.items):any(function(item)
        return item.label == "child.lua" and item.data.era_cmp.source == "path"
      end),
      "prefixed quoted path: " .. spec.line
    )
  end

  vim.fn.delete(root, "rf")
  cwd = initial_cwd
end)

t:test("apostrophes inside words do not capture later unquoted paths", function()
  local root = vim.fn.tempname()
  vim.fn.mkdir(root, "p")
  local filepath = vim.fs.joinpath(root, "child.lua")
  local file = assert(io.open(filepath, "wb"))
  file:write("return true\n")
  file:close()
  cwd = root

  for _, line in ipairs({ "don't ./ch", "users' ./ch", "café' ./ch", "café' ./ch", "f' ./ch" }) do
    local result = complete(line, "markdown", nil, vim.fs.joinpath(root, "note.md"))
    t.assert_true(
      vim.iter(result.items):any(function(item)
        return item.label == "child.lua" and item.data.era_cmp.source == "path"
      end),
      "apostrophe path boundary: " .. line
    )
  end

  vim.fn.delete(root, "rf")
  cwd = initial_cwd
end)

t:test("buffer completion preserves decomposed Unicode identifiers", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(bufnr, vim.fn.tempname() .. ".lua")
  vim.api.nvim_set_option_value("buftype", "", { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "caféValue" })
  t:patch_table(dot.tab, "resolve", function()
    return { bufs = { { bufnr = bufnr } } }
  end)

  local Buffer = require("era.m.cmp.source.buffer")
  local items = Buffer.complete({
    bufnr = bufnr,
    row = 0,
    col = 4,
    line = "cafe",
    filetype = "lua",
    start_col = 0,
    end_col = 4,
    keyword = "cafe",
  }, {})
  t.assert_true(
    vim.iter(items):any(function(item)
      return item.label == "caféValue"
    end),
    "decomposed identifier"
  )

  Buffer.clear(bufnr)
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("ordinary paths include dotfiles by default", function()
  local root = vim.fn.tempname()
  vim.fn.mkdir(root, "p")
  for _, name in ipairs({ ".secret", "sample" }) do
    local file = assert(io.open(vim.fs.joinpath(root, name), "wb"))
    file:write(name)
    file:close()
  end
  cwd = root

  local plain = complete("s", stl.filetype.UX_PICKER_FINDER)
  t.assert_true(
    vim.iter(plain.items):any(function(item)
      return item.label == ".secret"
    end),
    "hidden plain item"
  )
  local hidden = complete(".s", stl.filetype.UX_PICKER_FINDER)
  t.assert_true(
    vim.iter(hidden.items):any(function(item)
      return item.label == ".secret"
    end),
    "explicit hidden item"
  )

  vim.fn.delete(root, "rf")
  cwd = initial_cwd
end)

t:test("shared ranking preserves same-label candidates from distinct providers", function()
  local Util = require("era.m.cmp.source.util")
  local items = {
    Util.item("buffer", 100, { label = "function", kind = vim.lsp.protocol.CompletionItemKind.Text }),
    Util.item("dict", 95, { label = "function", kind = vim.lsp.protocol.CompletionItemKind.Text }),
    Util.item("lsp", 180, { label = "function", kind = vim.lsp.protocol.CompletionItemKind.Function }),
  }

  local output = Util.filter("fun", items)
  local lsp_meta = assert(output[1].data.era_cmp)
  local buffer_meta = assert(output[2].data.era_cmp)

  t.assert_eq(3, #output, "provider candidates")
  t.assert_eq("lsp", lsp_meta.source, "distinct function kind")
  t.assert_eq("buffer", buffer_meta.source, "highest duplicate source")
  t.assert_eq("dict", output[3].data.era_cmp.source, "lower duplicate source")
end)

t:test("path scanning continues beyond the first chunk", function()
  local Path = require("era.m.cmp.source.path")
  local handle = { index = 0 }
  t:patch_table(vim.uv, "fs_scandir", function(_, callback)
    vim.schedule(function()
      callback(nil, handle)
    end)
    return { cancel = function() end }
  end)
  t:patch_table(vim.uv, "fs_scandir_next", function(request)
    request.index = request.index + 1
    if request.index <= 200 then
      return string.format("skip-%03d", request.index), "file"
    end
    if request.index == 201 then
      return "target.lua", "file"
    end
    return nil
  end)

  local result
  Path.complete({
    bufnr = 0,
    row = 0,
    col = 6,
    line = "target",
    filetype = stl.filetype.UX_PICKER_FINDER,
    start_col = 0,
    end_col = 6,
    keyword = "target",
  }, function(items)
    result = items
  end)
  t.wait_until(function()
    return result ~= nil
  end, 1000, "chunked path result")
  t.assert_true(
    vim.iter(result):any(function(item)
      return item.label == "target.lua"
    end),
    "entry after first chunk"
  )
end)

t:test("slash commands require a whitespace boundary", function()
  for _, line in ipairs({ "foo/com", "https://example/com" }) do
    local result = complete(line, "markdown")
    t.assert_false(
      vim.iter(result.items):any(function(item)
        return item.data.era_cmp.source == "slash"
      end),
      "slash source: " .. line
    )
  end
end)

t:test("ordinary path completion rejects non-path slash syntax", function()
  local Path = require("era.m.cmp.source.path")
  local scans = {} ---@type string[]
  t:patch_table(vim.uv, "fs_scandir", function(dirname)
    scans[#scans + 1] = dirname
    return nil, "unexpected scan"
  end)

  for _, line in ipairs({ "//", "</", "1 /", "1 /f", "value /foo", "https://example/" }) do
    local result
    Path.complete({
      bufnr = 0,
      row = 0,
      col = #line,
      line = line,
      filetype = "lua",
      start_col = 0,
      end_col = #line,
      keyword = "",
    }, function(items)
      result = items
    end)
    t.assert_eq(0, #assert(result), "path items: " .. line)
  end
  t.assert_eq(0, #scans, "filesystem scans")
end)

t:test("shell completion preserves explicit absolute paths", function()
  local Path = require("era.m.cmp.source.path")
  local scans = {} ---@type string[]
  t:patch_table(vim.uv, "fs_scandir", function(dirname)
    scans[#scans + 1] = dirname
    return { cancel = function() end }
  end)

  for _, spec in ipairs({ { "cat /usr/lo", "sh" }, { "cd /Users/wa", "zsh" } }) do
    Path.complete({
      bufnr = 0,
      row = 0,
      col = #spec[1],
      line = spec[1],
      filetype = spec[2],
      start_col = 0,
      end_col = #spec[1],
      keyword = "",
    }, function() end)
  end
  t.assert_eq("/usr/", scans[1], "sh absolute directory")
  t.assert_eq("/Users/", scans[2], "zsh absolute directory")
end)

t:test("completion excludes ephemeral documentation buffers", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })
  vim.b[bufnr][dot.var.N_CMP_DOCUMENTATION] = true

  t.assert_false(Source.is_enabled(bufnr), "documentation buffer")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("cancelled path scan suppresses its callback", function()
  local Path = require("era.m.cmp.source.path")
  local scan_callback
  local cancel_count = 0
  t:patch_table(vim.uv, "fs_scandir", function(_, callback)
    scan_callback = callback
    return {
      cancel = function()
        cancel_count = cancel_count + 1
      end,
    }
  end)

  local callback_count = 0
  local cancel = Path.complete({
    bufnr = 0,
    row = 0,
    col = 3,
    line = "sam",
    filetype = stl.filetype.UX_PICKER_FINDER,
    start_col = 0,
    end_col = 3,
    keyword = "sam",
  }, function()
    callback_count = callback_count + 1
  end)
  cancel()
  scan_callback(nil, {})
  vim.wait(20)

  t.assert_eq(1, cancel_count, "filesystem cancellation")
  t.assert_eq(0, callback_count, "late callback")
end)

t:test("buffer words are cached by changedtick", function()
  local Buffer = require("era.m.cmp.source.buffer")
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(bufnr, vim.fn.tempname() .. ".lua")
  vim.api.nvim_set_option_value("buftype", "", { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "future future feature" })
  dot.tab.resolve = function()
    return { bufs = { { bufnr = bufnr } } }
  end

  local read_count = 0
  local get_lines = vim.api.nvim_buf_get_lines
  t:patch_table(vim.api, "nvim_buf_get_lines", function(...)
    read_count = read_count + 1
    return get_lines(...)
  end)

  local context = {
    bufnr = bufnr,
    row = 0,
    col = 3,
    line = "fut",
    filetype = "lua",
    start_col = 0,
    end_col = 3,
    keyword = "fut",
  }
  Buffer.complete(context)
  Buffer.complete(context)
  t.assert_eq(1, read_count, "buffer reads")

  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("buffer completion excludes sensitive tab buffers", function()
  local request_bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(request_bufnr, vim.fn.tempname() .. ".lua")
  vim.api.nvim_set_option_value("buftype", "", { buf = request_bufnr })
  vim.api.nvim_buf_set_lines(request_bufnr, 0, -1, false, { "SENS" })
  local sensitive_bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(sensitive_bufnr, vim.fs.joinpath(vim.fn.tempname(), ".env.private"))
  vim.api.nvim_set_option_value("buftype", "", { buf = sensitive_bufnr })
  vim.api.nvim_buf_set_lines(sensitive_bufnr, 0, -1, false, { "SENSITIVE_COMPLETION_SENTINEL" })
  t:patch_table(dot.tab, "resolve", function()
    return { bufs = { { bufnr = request_bufnr }, { bufnr = sensitive_bufnr } } }
  end)

  local Buffer = require("era.m.cmp.source.buffer")
  local items = Buffer.complete({
    bufnr = request_bufnr,
    row = 0,
    col = 4,
    line = "SENS",
    filetype = "lua",
    start_col = 0,
    end_col = 4,
    keyword = "SENS",
  })
  t.assert_false(
    vim.iter(items):any(function(item)
      return item.label == "SENSITIVE_COMPLETION_SENTINEL"
    end),
    "sensitive buffer word"
  )

  vim.api.nvim_buf_delete(request_bufnr, { force = true })
  vim.api.nvim_buf_delete(sensitive_bufnr, { force = true })
end)

t:test("buffer completion ranks matches beyond the old extraction limit", function()
  local request_bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(request_bufnr, vim.fn.tempname() .. ".lua")
  vim.api.nvim_set_option_value("buftype", "", { buf = request_bufnr })
  local words = {} ---@type string[]
  for index = 1, 1100 do
    words[index] = string.format("word_%04d", index)
  end
  words[#words + 1] = "targetword"
  vim.api.nvim_buf_set_lines(request_bufnr, 0, -1, false, { table.concat(words, " ") })
  t:patch_table(dot.tab, "resolve", function()
    return { bufs = { { bufnr = request_bufnr } } }
  end)

  local Buffer = require("era.m.cmp.source.buffer")
  local items = Buffer.complete({
    bufnr = request_bufnr,
    row = 0,
    col = 4,
    line = "targ",
    filetype = "lua",
    start_col = 0,
    end_col = 4,
    keyword = "targ",
  })
  t.assert_true(
    vim.iter(items):any(function(item)
      return item.label == "targetword"
    end),
    "late matching word"
  )

  vim.api.nvim_buf_delete(request_bufnr, { force = true })
end)

t:test("buffer completion applies frecency before the output limit", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(bufnr, vim.fn.tempname() .. ".lua")
  vim.api.nvim_set_option_value("buftype", "", { buf = bufnr })
  local words = {} ---@type string[]
  for index = 1, 500 do
    words[index] = string.format("target%03d", index)
  end
  words[#words + 1] = "aatarget"
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { table.concat(words, " ") })
  t:patch_table(dot.tab, "resolve", function()
    return { bufs = { { bufnr = bufnr } } }
  end)

  local Buffer = require("era.m.cmp.source.buffer")
  local items = Buffer.complete({
    bufnr = bufnr,
    row = 0,
    col = 6,
    line = "target",
    filetype = "lua",
    start_col = 0,
    end_col = 6,
    keyword = "target",
  }, {
    ["buffer\0aatarget"] = { count = 12, last_used = os.time() },
  })
  t.assert_eq("aatarget", items[1].label, "frecency-ranked item")

  Buffer.clear(bufnr)
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("buffer completion keeps cached tab-scale ranking below 100ms", function()
  local bufnrs = {} ---@type integer[]
  local tab_bufs = {} ---@type { bufnr: integer }[]
  for buffer_index = 1, 10 do
    local bufnr = vim.api.nvim_create_buf(false, true)
    bufnrs[#bufnrs + 1] = bufnr
    tab_bufs[#tab_bufs + 1] = { bufnr = bufnr }
    vim.api.nvim_buf_set_name(bufnr, vim.fn.tempname() .. ".lua")
    vim.api.nvim_set_option_value("buftype", "", { buf = bufnr })
    local words = {} ---@type string[]
    for word_index = 1, 14500 do
      words[word_index] = string.format("wo%d%05d", buffer_index - 1, word_index)
    end
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { table.concat(words, " ") })
  end
  t:patch_table(dot.tab, "resolve", function()
    return { bufs = tab_bufs }
  end)

  local Buffer = require("era.m.cmp.source.buffer")
  local context = {
    bufnr = bufnrs[1],
    row = 0,
    col = 2,
    line = "wo",
    filetype = "lua",
    start_col = 0,
    end_col = 2,
    keyword = "wo",
  }
  Buffer.complete(context, {})
  local started = vim.uv.hrtime()
  local items = Buffer.complete(context, {})
  local elapsed_ms = (vim.uv.hrtime() - started) / 1000000
  t.assert_eq(200, #items, "bounded result count")
  t.assert_true(elapsed_ms < 100, string.format("cached completion %.1fms", elapsed_ms))

  for _, bufnr in ipairs(bufnrs) do
    Buffer.clear(bufnr)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end)

t:test("friendly snippet prefixes and transforms preserve their declared syntax", function()
  local Snippets = require("era.m.cmp.source.snippets")
  local friendly = vim.fs.joinpath(vim.fn.stdpath("data"), "lazy", "friendly-snippets")
  t.assert_true(vim.uv.fs_stat(friendly) ~= nil, "friendly-snippets installation")
  if not vim.list_contains(vim.api.nvim_list_runtime_paths(), friendly) then
    vim.opt.runtimepath:append(friendly)
  end
  Snippets.clear_cache()

  local function snippet(line, label)
    local filepath = vim.fs.joinpath(vim.fn.tempname(), "include", "widget.h")
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, filepath)
    vim.api.nvim_set_option_value("filetype", "cpp", { buf = bufnr })
    local start_col, end_col = yoz.cmp.keyword_range(line, #line, true)
    local items = Snippets.complete({
      bufnr = bufnr,
      row = 0,
      col = #line,
      line = line,
      filetype = "cpp",
      start_col = start_col,
      end_col = end_col,
      keyword = line:sub(start_col + 1),
    })
    vim.api.nvim_buf_delete(bufnr, { force = true })
    return assert(vim.iter(items):find(function(item)
      return item.label == label
    end))
  end

  local include = snippet("#inc", "#inc")
  t.assert_eq(0, include.textEdit.range.start.character, "complete punctuation prefix")
  t.assert_true(include.textEdit.newText:find('#include "', 1, true) ~= nil, "include body")

  local partial = snippet("#", "#inc")
  t.assert_eq(0, partial.textEdit.range.start.character, "partial punctuation prefix")
  t.assert_true(Snippets.trigger_characters("cpp")["#"], "punctuation trigger")

  local guard = snippet("#guard", "#guard")
  t.assert_eq(0, guard.textEdit.range.start.character, "guard prefix")
  t.assert_true(guard.textEdit.newText:find("INCLUDE_INCLUDE_WIDGET_H_", 1, true) ~= nil, "guard transform")
  t.assert_false(guard.textEdit.newText:find("${TM_", 1, true) ~= nil, "resolved transforms")
  t.assert_true(pcall(vim.lsp._snippet_grammar.parse, guard.textEdit.newText), "valid transformed snippet")
end)

t:test("snippet variables are expanded for the request buffer", function()
  local Snippets = require("era.m.cmp.source.snippets")
  local friendly = vim.fs.joinpath(vim.fn.stdpath("data"), "lazy", "friendly-snippets")
  t.assert_true(vim.uv.fs_stat(friendly) ~= nil, "friendly-snippets installation")
  vim.opt.runtimepath:append(friendly)
  Snippets.clear_cache()

  local function class_snippet(filename)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, vim.fs.joinpath(vim.fn.tempname(), filename))
    vim.api.nvim_set_option_value("filetype", "kotlin", { buf = bufnr })
    local items = Snippets.complete({
      bufnr = bufnr,
      row = 0,
      col = 5,
      line = "class",
      filetype = "kotlin",
      start_col = 0,
      end_col = 5,
      keyword = "class",
    })
    vim.api.nvim_buf_delete(bufnr, { force = true })
    return vim.iter(items):find(function(item)
      return item.label == "class"
    end)
  end

  local first = assert(class_snippet("First.kt"))
  local second = assert(class_snippet("Second.kt"))
  local special = assert(class_snippet("Foo$1.kt"))
  t.assert_true(first.textEdit.newText:find("class First", 1, true) ~= nil, "first filename")
  t.assert_true(second.textEdit.newText:find("class Second", 1, true) ~= nil, "second filename")
  local preview = tostring(vim.lsp._snippet_grammar.parse(special.textEdit.newText))
  t.assert_true(preview:find("class Foo$1", 1, true) ~= nil, "escaped filename")

  t:patch_table(vim.uv, "random", function(size)
    t.assert_eq(16, size, "UUID byte count")
    return string.char(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15)
  end)

  local function global_snippets(keyword, filetype)
    filetype = filetype or "text"
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value("filetype", filetype, { buf = bufnr })
    local items = Snippets.complete({
      bufnr = bufnr,
      row = 0,
      col = #keyword,
      line = keyword,
      filetype = filetype,
      start_col = 0,
      end_col = #keyword,
      keyword = keyword,
    })
    vim.api.nvim_buf_delete(bufnr, { force = true })
    return items
  end

  local date_before = os.date("%Y-%m-%d")
  local date_items = vim
    .iter(global_snippets("date"))
    :filter(function(item)
      return item.label == "date"
    end)
    :totable()
  local date_after = os.date("%Y-%m-%d")
  t.assert_eq(1, #date_items, "deduplicated date snippet")
  t.assert_true(
    date_items[1].textEdit.newText == date_before or date_items[1].textEdit.newText == date_after,
    "current date"
  )

  local uuid_items = vim
    .iter(global_snippets("uuid"))
    :filter(function(item)
      return item.label == "uuid"
    end)
    :totable()
  t.assert_eq(1, #uuid_items, "deduplicated UUID snippet")
  t.assert_eq("00010203-0405-4607-8809-0a0b0c0d0e0f", uuid_items[1].textEdit.newText, "UUID v4")
  local lua_uuid = assert(vim.iter(global_snippets("uuid", "lua")):find(function(item)
    return item.label == "uuid"
  end))
  t.assert_false(
    uuid_items[1].data.era_cmp.usage_key == lua_uuid.data.era_cmp.usage_key,
    "filetype-scoped snippet usage"
  )
end)

t:test("friendly snippet variables match the Blink builtin contract", function()
  local Snippets = require("era.m.cmp.source.snippets")
  local installed = vim.fs.joinpath(vim.fn.stdpath("data"), "lazy", "friendly-snippets")
  if not vim.list_contains(vim.api.nvim_list_runtime_paths(), installed) then
    vim.opt.runtimepath:append(installed)
  end

  local formats = {
    ["%Y"] = "2026",
    ["%y"] = "26",
    ["%m"] = "08",
    ["%B"] = "August",
    ["%b"] = "Aug",
    ["%d"] = "31",
    ["%A"] = "Monday",
    ["%a"] = "Mon",
    ["%H"] = "13",
    ["%M"] = "14",
    ["%S"] = "15",
  }
  t:patch_table(os, "date", function(format)
    if format == "!*t" or format == "*t" then
      return { year = 2026, month = 8, day = 31, hour = 13, min = 14, sec = 15, isdst = false }
    end
    return assert(formats[format], "unexpected date format: " .. tostring(format))
  end)
  t:patch_table(os, "time", function()
    return 123456
  end)
  t:patch_table(vim.uv, "random", function(size)
    if size == 16 then
      return string.char(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15)
    end
    if size == 4 then
      return string.char(0, 0, 0, 42)
    end
    if size == 3 then
      return string.char(0xab, 0xcd, 0xef)
    end
    error("unexpected random byte count: " .. size)
  end)
  local register = "picked" ---@type string
  t:patch_table(vim.fn, "getreg", function()
    return register
  end)

  local function snippet(keyword, filetype, filepath, commentstring)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, filepath)
    vim.api.nvim_set_option_value("filetype", filetype, { buf = bufnr })
    vim.api.nvim_set_option_value("commentstring", commentstring or "", { buf = bufnr })
    local items = Snippets.complete({
      bufnr = bufnr,
      row = 0,
      col = #keyword,
      line = keyword,
      filetype = filetype,
      start_col = 0,
      end_col = #keyword,
      keyword = keyword,
    })
    vim.api.nvim_buf_delete(bufnr, { force = true })
    return assert(vim.iter(items):find(function(item)
      return item.label == keyword
    end))
  end

  Snippets.clear_cache()
  local timestamp = snippet("ts", "r", vim.fs.joinpath(cwd, "sample.r"))
  t.assert_eq("# Mon Aug 31 13:14:15 2026 ------------------------------\n", timestamp.textEdit.newText, "R timestamp")

  local root = vim.fn.tempname()
  local friendly = vim.fs.joinpath(root, "friendly-snippets")
  vim.fn.mkdir(friendly, "p")
  vim.fn.writefile({
    vim.json.encode({
      contributes = {
        snippets = {
          { language = "cmpbuiltin", path = "./snippets.json" },
        },
      },
    }),
  }, vim.fs.joinpath(friendly, "package.json"))
  vim.fn.writefile({
    vim.json.encode({
      builtin = {
        prefix = "builtin",
        body = {
          "${TM_SELECTED_TEXT}|${CLIPBOARD}",
          "${RELATIVE_FILEPATH}|${WORKSPACE_FOLDER}|${WORKSPACE_NAME}",
          "${CURRENT_YEAR}|${CURRENT_YEAR_SHORT}|${CURRENT_MONTH}|${CURRENT_MONTH_NAME}|${CURRENT_MONTH_NAME_SHORT}|${CURRENT_DATE}|${CURRENT_DAY_NAME}|${CURRENT_DAY_NAME_SHORT}|${CURRENT_HOUR}|${CURRENT_MINUTE}|${CURRENT_SECOND}|${CURRENT_SECONDS_UNIX}|${CURRENT_TIMEZONE_OFFSET}",
          "${RANDOM}|${RANDOM_HEX}|${UUID}",
          "${LINE_COMMENT}|${BLOCK_COMMENT_START}|${BLOCK_COMMENT_END}",
        },
      },
      defaulted = {
        prefix = "defaulted",
        body = "${TM_SELECTED_TEXT:${1:text}}|${CURRENT_YEAR:year}",
      },
    }),
  }, vim.fs.joinpath(friendly, "snippets.json"))
  vim.opt.runtimepath:append(friendly)
  t:_register_cleanup(function()
    vim.opt.runtimepath:remove(friendly)
    Snippets.clear_cache()
    vim.fn.delete(root, "rf")
  end)

  local workspace = vim.fs.joinpath(root, "workspace")
  local filepath = vim.fs.joinpath(workspace, "nested", "main.lua")
  t:patch_table(vim.lsp, "get_clients", function(opts)
    t.assert_true(type(opts) == "table" and type(opts.bufnr) == "number", "request buffer LSP scope")
    return {
      { workspace_folders = { { name = workspace, uri = vim.uri_from_fname(workspace) } } },
    }
  end)

  Snippets.clear_cache()
  local builtin = snippet("builtin", "cmpbuiltin", filepath, "/* %s */")
  t.assert_eq(
    table.concat({
      "picked|picked",
      string.format("nested/main.lua|%s|%s", workspace, yoz.path.basename(workspace)),
      "2026|26|08|August|Aug|31|Monday|Mon|13|14|15|123456|+00:00",
      "000042|abcdef|00010203-0405-4607-8809-0a0b0c0d0e0f",
      "//|/*|*/",
    }, "\n"),
    builtin.textEdit.newText,
    "Blink builtin variables"
  )

  register = ""
  Snippets.clear_cache()
  local defaulted = snippet("defaulted", "cmpbuiltin", filepath)
  t.assert_eq("${1:text}|2026", defaulted.textEdit.newText, "builtin variable defaults")
end)

t:run()
