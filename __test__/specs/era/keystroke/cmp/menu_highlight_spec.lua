local harness = require("__test__.support.harness")
local UI = require("__test__.support.ui")
local Grid = require("__test__.support.ui_grid")
local t = harness.new()

---@param options                       table
---@return __test__.support.UI
---@return table
local function editor(options)
  local ui = UI.new()
  t:defer(function()
    ui:close()
  end)
  local grid = Grid.new(ui)
  ui:start({ width = 100, height = 35 })
  ui:lua(
    [[
    local options = ...
    require('__test__.support.cmp.behavior').setup(options)
    local deprecated = vim.api.nvim_get_hl(0,{name='CmpLabelDeprecated',link=false})
    assert(deprecated.strikethrough and deprecated.fg == nil and deprecated.bg == nil,'decoration-only fallback')
    local cmp_stl, cmp_dot = stl, dot
    stl, dot = require('stl'), require('dot')
    dot.context.theme.apply_theme({theme='vsc-dark-modern',transparency=false})
    stl, dot = cmp_stl, cmp_dot
    vim.o.pumblend = 0
  ]],
    options
  )
  t:defer(function()
    t.assert_eq("", ui:lua([[return vim.v.errmsg]]), "no editor errors")
  end)
  return ui, grid
end

---@param ui                           table
---@param code                          string
---@param message                       string
---@return nil
local function wait(ui, code, message)
  local ok = pcall(ui.wait_until, ui, function()
    return ui:lua(code)
  end, 1000)
  if not ok then
    message = message
      .. ": "
      .. vim.inspect(ui:lua([[return {lines=vim.api.nvim_buf_get_lines(0,0,-1,false),mode=vim.api.nvim_get_mode()}]]))
  end
  t.assert_true(ok, message)
end

---@param ui                           table
---@param grid                          table
---@return table[]
local function matching_cells(ui, grid)
  local cells = ui:lua([[
    local geometry, cells = vim.fn.pum_getpos(), {}
    if vim.fn.pumvisible() == 0 then return cells end
    for row = math.max(1,geometry.row), math.min(vim.o.lines,geometry.row+geometry.height+3) do
      for col = math.max(1,geometry.col), math.min(vim.o.columns,geometry.col+geometry.width+4) do
        local text = vim.fn.screenstring(row,col)
        if text == 'a' or text == 'p' then
          cells[#cells+1] = {text=text,row=row,col=col,attribute=vim.fn.screenattr(row,col)}
        end
      end
    end
    return cells
  ]])
  local matches = {}
  for _, cell in ipairs(cells) do
    local style = grid.highlights[cell.attribute] or {}
    if style.foreground == 0xf5a9b8 then
      cell.style = style
      matches[#matches + 1] = cell
    end
  end
  return matches
end

---@param ui                           table
---@param grid                          table
---@param selected                      integer
---@param deprecated                    ?boolean
---@return nil
local function assert_matches(ui, grid, selected, deprecated)
  local matches = matching_cells(ui, grid)
  t.assert_eq(4, #matches, "both displayed candidates highlight their nonadjacent a/p")
  for index, cell in ipairs(matches) do
    t.assert_eq(index % 2 == 1 and "a" or "p", cell.text, "matched character")
    t.assert_true(cell.style.bold and cell.style.italic, "matched character keeps bold and italic")
    t.assert_eq(
      math.floor((index - 1) / 2) == selected and 0x0078d4 or 0x1f1f1f,
      cell.style.background,
      "selected and unselected menu backgrounds remain intact"
    )
    if deprecated then
      t.assert_true(cell.style.strikethrough, "deprecated markers retain their strike-through")
    end
  end
end

for _, prefix in ipairs({ "obj.", "😀 obj." }) do
  t:test("wide LSP edits highlight and restore the keyword after " .. prefix, function()
    local items = {}
    for _, label in ipairs({ "alpha_one", "alpha_two" }) do
      items[#items + 1] = {
        label = label,
        textEdit = {
          range = {
            start = { line = 0, character = 0 },
            ["end"] = {
              line = 0,
              character = vim.str_utfindex(prefix .. "ap", "utf-16"),
            },
          },
          newText = prefix .. label,
        },
      }
    end
    local ui, grid = editor({ lines = { prefix }, items = items })
    ui:rpc("nvim_input", "Aap")
    wait(ui, [[return vim.fn.complete_info({'selected'}).selected == 0]], "ranked menu")
    assert_matches(ui, grid, 0)
    ui:rpc("nvim_input", "<C-j>")
    wait(
      ui,
      "return vim.api.nvim_get_current_line() == " .. string.format("%q", prefix .. "alpha_two"),
      "wide edit previews its suffix without duplicating the namespace"
    )
    assert_matches(ui, grid, 1)
    ui:rpc("nvim_input", "<C-e>")
    wait(
      ui,
      "return vim.fn.pumvisible() == 0 and vim.api.nvim_get_current_line() == " .. string.format("%q", prefix .. "ap"),
      "cancellation restores the original keyword"
    )
    ui:rpc("nvim_input", "<C-Space>")
    wait(ui, [[return vim.fn.complete_info({'selected'}).selected == 0]], "reopened menu")
    if prefix == "obj." then
      ui:rpc("nvim_input", "<CR>")
    else
      ui:lua([[vim.api.nvim_select_popupmenu_item(0,true,true,{})]])
    end
    wait(
      ui,
      "return vim.fn.pumvisible() == 0 and vim.api.nvim_get_current_line() == "
        .. string.format("%q", prefix .. "alpha_one"),
      "acceptance applies the complete LSP edit"
    )
  end)
end

t:test("mixed LSP filter ranges share a highlighted query suffix", function()
  local range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 6 } }
  local ui, grid = editor({
    lines = { "obj." },
    items = {
      { label = "alpha_one", textEdit = { range = range, newText = "obj.alpha_one" } },
      { label = "obj.alpha_two", textEdit = { range = range, newText = "obj.alpha_two" } },
    },
  })
  ui:rpc("nvim_input", "Aap")
  wait(ui, [[return vim.fn.complete_info({'selected'}).selected == 0]], "mixed filter queries")
  assert_matches(ui, grid, 0)
end)

t:test("a wide edit that changes the namespace waits for acceptance", function()
  local ui = editor({
    lines = { "obj." },
    items = {
      {
        label = "alpha_one",
        textEdit = {
          range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 6 } },
          newText = "other.alpha_one",
        },
      },
    },
  })
  ui:rpc("nvim_input", "Aap")
  wait(ui, [[return vim.fn.complete_info({'selected'}).selected == 0]], "wide replacement menu")
  t.assert_eq("ap", ui:lua([[return vim.fn.complete_info({'items'}).items[1].word]]), "safe native preview")
  ui:lua([[vim.api.nvim_select_popupmenu_item(0,true,true,{})]])
  wait(
    ui,
    [[return vim.fn.pumvisible() == 0 and vim.api.nvim_get_current_line() == 'other.alpha_one']],
    "native acceptance still replaces the complete namespace"
  )
end)

t:test("both deprecated markers keep pink matches on selected and unselected rows", function()
  local ui, grid =
    editor({ items = { { label = "alpha_one", deprecated = true }, { label = "alpha_two", tags = { 1 } } } })
  ui:rpc("nvim_input", "iap")
  wait(ui, [[return vim.fn.complete_info({'selected'}).selected == 0]], "deprecated menu")
  assert_matches(ui, grid, 0, true)
  ui:rpc("nvim_input", "<C-j>")
  wait(ui, [[return vim.fn.complete_info({'selected'}).selected == 1]], "selected tagged candidate")
  assert_matches(ui, grid, 1, true)
end)

for _, prefix in ipairs({ "obj.", "😀 obj." }) do
  t:test("wide acceptance records dot repeat after a projected preview for " .. prefix, function()
    local result = prefix .. "alpha_one"
    local ui = editor({
      lines = { prefix, prefix },
      items = {
        {
          label = "alpha_one",
          textEdit = {
            range = {
              start = { line = 0, character = 0 },
              ["end"] = { line = 0, character = vim.str_utfindex(prefix .. "ap", "utf-16") },
            },
            newText = result,
          },
        },
      },
    })
    ui:rpc("nvim_input", "Aap")
    wait(ui, [[return vim.fn.complete_info({'selected'}).selected == 0]], "wide replacement menu")
    ui:lua([[vim.api.nvim_select_popupmenu_item(0,true,false,{})]])
    wait(ui, "return vim.api.nvim_get_current_line() == " .. string.format("%q", result), "projected preview")
    ui:rpc("nvim_input", "<CR>")
    wait(ui, [[return vim.fn.pumvisible() == 0]], "accepted wide edit")
    ui:rpc("nvim_input", "<Esc>j$.")
    wait(
      ui,
      "return vim.api.nvim_buf_get_lines(0,1,2,false)[1] == " .. string.format("%q", result),
      "dot repeat applies the complete edit at the second namespace"
    )
  end)
end

t:test("wide snippets project their preview without trimming the accepted snippet", function()
  local ui = editor({
    lines = { "obj." },
    items = {
      {
        label = "alpha_snippet",
        kind = 15,
        insertTextFormat = 2,
        textEdit = {
          range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 6 } },
          newText = "obj.alpha_${1:value}$0",
        },
      },
    },
  })
  ui:rpc("nvim_input", "Aap")
  wait(ui, [[return vim.fn.complete_info({'selected'}).selected == 0]], "wide snippet menu")
  t.assert_eq(
    "alpha_value",
    ui:lua([[return vim.fn.complete_info({'items'}).items[1].word]]),
    "projected snippet prefix"
  )
  ui:lua([[vim.api.nvim_select_popupmenu_item(0,true,false,{})]])
  wait(ui, [[return vim.api.nvim_get_current_line() == 'obj.alpha_value']], "native snippet preview")
  ui:rpc("nvim_input", "<CR>")
  wait(
    ui,
    [[return vim.snippet.active() and vim.api.nvim_get_current_line() == 'obj.alpha_value']],
    "the original wide snippet still owns its placeholder"
  )
  ui:rpc("nvim_input", "replacement<Tab>")
  wait(ui, [[return vim.api.nvim_get_current_line() == 'obj.alpha_replacement']], "placeholder editing")
end)

t:run()
