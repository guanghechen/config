---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.fn.find_lsp_symbols" ---@type string

local t = require("__test__.support.harness").new("era.fn.find_lsp_symbols")

t:test("symbol preview clears its range when the filter or source removes the target", function()
  local filepath = vim.fn.tempname() .. ".lua"
  vim.fn.writefile({ "local function sample()", "  return true", "end" }, filepath)
  t:defer(function()
    vim.fn.delete(filepath)
  end)
  local ui = require("__test__.support.ui").new()
  t:defer(function()
    ui:close()
  end)
  ui:rpc("nvim_ui_attach", 160, 50, { rgb = true, ext_linegrid = true })
  ui:rpc(
    "nvim_exec_lua",
    [[
    local root, filepath = ...
    vim.opt.runtimepath:prepend(root)
    package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
    require("ark.bootstrap").setup()
    errors = {}
    stl.reporter.error = function(report) errors[#errors + 1] = report end
    current_source = assert(dot.buf.loadfile(filepath))
    dot.tab.retrieve_bufnr_sourcefile = function() return current_source end
    controls = {}
    for key, value in pairs({
      search_pattern = "", flag_fuzzy = false, flag_regex = false,
      flag_case_sensitive = false, flag_viewtype = "tree", flag_foldempty = true,
    }) do
      controls[key] = stl.c.Observable.from_value(value)
    end
    dot.context.select.lsp_symbols = controls
    local client = {
      offset_encoding = "utf-8",
      server_capabilities = {documentSymbolProvider = true},
      request = function(_, _, _, callback)
        callback(nil, {{
          name = "sample", kind = vim.lsp.protocol.SymbolKind.Function,
          range = {start = {line = 0, character = 0}, ["end"] = {line = 2, character = 3}},
          selectionRange = {start = {line = 0, character = 15}, ["end"] = {line = 0, character = 21}},
        }})
        return true, 1
      end,
    }
    vim.lsp.get_clients = function() return {client} end
    local new = era.m.picker.TreeComposer.new
    era.m.picker.TreeComposer.new = function(props)
      composer = new(props)
      return composer
    end
    find_symbols = assert(loadfile(root .. "/lua/era/fn/find-lsp-symbols.lua"))()
    find_symbols()
    preview = composer.preview
  ]],
    { assert(vim.uv.cwd()), filepath }
  )

  ---@param title                       ?string
  ---@param has_range                   boolean
  ---@return table
  local function wait_preview(title, has_range)
    local snapshot
    t.wait_until(function()
      snapshot = ui:rpc(
        "nvim_exec_lua",
        [[
        local result = preview._last_result
        local bufnr, winnr = preview:get_bufnr(), preview:get_winnr()
        local marks = bufnr and vim.api.nvim_buf_get_extmarks(bufnr, dot.var.nsnr.picker_preview_visual, 0, -1, {}) or {}
        return {
          title = result and result.title, has_range = result and result.has_range == true or false,
          marks = #marks, winhighlight = winnr and vim.api.nvim_get_option_value("winhighlight", {win = winnr}),
          errors = errors,
        }
      ]],
        {}
      )
      return snapshot.title ~= nil and (title == nil or snapshot.title == title) and snapshot.has_range == has_range
    end, 5000)
    t.assert_eq(0, #snapshot.errors, vim.inspect(snapshot.errors))
    return snapshot
  end

  local ranged = wait_preview(nil, true)
  t.assert_true(ranged.marks > 0)
  t.assert_true(ranged.winhighlight:find("CursorLine:m_pk_preview_range_current", 1, true) ~= nil)

  ui:rpc("nvim_exec_lua", [[controls.search_pattern:next("no_matching_symbol")]], {})
  local empty = wait_preview("No Symbol Selected", false)
  t.assert_eq(0, empty.marks, "empty results clear the previous range")
  t.assert_true(empty.winhighlight:find("CursorLine:m_pk_preview_current", 1, true) ~= nil)

  ui:rpc("nvim_exec_lua", [[controls.search_pattern:next("")]], {})
  t.assert_true(wait_preview(nil, true).marks > 0)
  ui:rpc("nvim_exec_lua", [[current_source = nil; find_symbols()]], {})
  local missing = wait_preview("No Source File", false)
  t.assert_eq(0, missing.marks, "missing sources clear the previous range")
  t.assert_true(missing.winhighlight:find("CursorLine:m_pk_preview_current", 1, true) ~= nil)
end)

t:run()
