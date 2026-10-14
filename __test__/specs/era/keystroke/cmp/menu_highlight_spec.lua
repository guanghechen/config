---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.keystroke.cmp.menu_highlight" ---@type string

local harness = require("__test__.support.harness")
local Rpc = require("__test__.support.rpc")
local t = harness.new("era.keystroke.cmp.menu_highlight")

---@param options                       table
---@return table
local function editor(options)
  local root = assert(vim.uv.cwd())
  local rpc = Rpc.new(root)
  t:defer(function()
    rpc:close()
  end)
  rpc:request("nvim_ui_attach", { 100, 35, { ext_linegrid = true, rgb = true } })
  rpc:lua(
    [[
    local root, options = ...
    vim.opt.runtimepath:prepend(root)
    package.path = root .. '/?.lua;' .. root .. '/?/init.lua;' .. package.path
    options.engine = 'era'
    require('__test__.fixtures.era.keystroke.cmp.behavior').setup(options)
    local deprecated = vim.api.nvim_get_hl(0,{name='CmpLabelDeprecated',link=false})
    assert(deprecated.strikethrough and deprecated.fg == nil and deprecated.bg == nil,'decoration-only fallback')
    local cmp_stl, cmp_dot = stl, dot
    stl, dot = require('stl'), require('dot')
    dot.context.theme.apply_theme({theme='vsc-dark-modern',transparency=false})
    stl, dot = cmp_stl, cmp_dot
    vim.o.pumblend = 0
  ]],
    root,
    options
  )
  t:defer(function()
    t.assert_eq("", rpc:lua([[return vim.v.errmsg]]), "no editor errors")
  end)
  return rpc
end

---@param rpc                           table
---@param code                          string
---@param message                       string
---@return nil
local function wait(rpc, code, message)
  local ok = Rpc.wait(1000, function()
    return rpc:lua(code)
  end, 5)
  if not ok then
    message = message
      .. ": "
      .. vim.inspect(rpc:lua([[return {lines=vim.api.nvim_buf_get_lines(0,0,-1,false),mode=vim.api.nvim_get_mode()}]]))
  end
  t.assert_true(ok, message)
end

---@param rpc                           table
---@return table[]
local function matching_cells(rpc)
  local cells = rpc:lua([[
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
  local attributes = {}
  for _, event in ipairs(rpc.notifications) do
    if event.method == "redraw" then
      for _, update in ipairs(event.args) do
        if update[1] == "hl_attr_define" then
          for index = 2, #update do
            attributes[update[index][1]] = update[index][2]
          end
        end
      end
    end
  end
  local matches = {}
  for _, cell in ipairs(cells) do
    local style = attributes[cell.attribute] or {}
    if style.foreground == 0xf5a9b8 then
      cell.style = style
      matches[#matches + 1] = cell
    end
  end
  return matches
end

---@param rpc                           table
---@param selected                      integer
---@param deprecated                    ?boolean
---@return nil
local function assert_matches(rpc, selected, deprecated)
  local matches = matching_cells(rpc)
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
    local rpc = editor({ lines = { prefix }, items = items })
    rpc:request("nvim_input", { "Aap" })
    wait(rpc, [[return vim.fn.complete_info({'selected'}).selected == 0]], "ranked menu")
    assert_matches(rpc, 0)
    rpc:request("nvim_input", { "<C-j>" })
    wait(
      rpc,
      "return vim.api.nvim_get_current_line() == " .. string.format("%q", prefix .. "alpha_two"),
      "wide edit previews its suffix without duplicating the namespace"
    )
    assert_matches(rpc, 1)
    rpc:request("nvim_input", { "<C-e>" })
    wait(
      rpc,
      "return vim.fn.pumvisible() == 0 and vim.api.nvim_get_current_line() == " .. string.format("%q", prefix .. "ap"),
      "cancellation restores the original keyword"
    )
    rpc:request("nvim_input", { "<C-Space>" })
    wait(rpc, [[return vim.fn.complete_info({'selected'}).selected == 0]], "reopened menu")
    if prefix == "obj." then
      rpc:request("nvim_input", { "<CR>" })
    else
      rpc:lua([[vim.api.nvim_select_popupmenu_item(0,true,true,{})]])
    end
    wait(
      rpc,
      "return vim.fn.pumvisible() == 0 and vim.api.nvim_get_current_line() == "
        .. string.format("%q", prefix .. "alpha_one"),
      "acceptance applies the complete LSP edit"
    )
  end)
end

t:test("mixed LSP filter ranges share a highlighted query suffix", function()
  local range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 6 } }
  local rpc = editor({
    lines = { "obj." },
    items = {
      { label = "alpha_one", textEdit = { range = range, newText = "obj.alpha_one" } },
      { label = "obj.alpha_two", textEdit = { range = range, newText = "obj.alpha_two" } },
    },
  })
  rpc:request("nvim_input", { "Aap" })
  wait(rpc, [[return vim.fn.complete_info({'selected'}).selected == 0]], "mixed filter queries")
  assert_matches(rpc, 0)
end)

t:test("a wide edit that changes the namespace waits for acceptance", function()
  local rpc = editor({
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
  rpc:request("nvim_input", { "Aap" })
  wait(rpc, [[return vim.fn.complete_info({'selected'}).selected == 0]], "wide replacement menu")
  t.assert_eq("ap", rpc:lua([[return vim.fn.complete_info({'items'}).items[1].word]]), "safe native preview")
  rpc:lua([[vim.api.nvim_select_popupmenu_item(0,true,true,{})]])
  wait(
    rpc,
    [[return vim.fn.pumvisible() == 0 and vim.api.nvim_get_current_line() == 'other.alpha_one']],
    "native acceptance still replaces the complete namespace"
  )
end)

t:test("both deprecated markers keep pink matches on selected and unselected rows", function()
  local rpc = editor({ items = { { label = "alpha_one", deprecated = true }, { label = "alpha_two", tags = { 1 } } } })
  rpc:request("nvim_input", { "iap" })
  wait(rpc, [[return vim.fn.complete_info({'selected'}).selected == 0]], "deprecated menu")
  assert_matches(rpc, 0, true)
  rpc:request("nvim_input", { "<C-j>" })
  wait(rpc, [[return vim.fn.complete_info({'selected'}).selected == 1]], "selected tagged candidate")
  assert_matches(rpc, 1, true)
end)

for _, prefix in ipairs({ "obj.", "😀 obj." }) do
  t:test("wide acceptance records dot repeat after a projected preview for " .. prefix, function()
    local result = prefix .. "alpha_one"
    local rpc = editor({
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
    rpc:request("nvim_input", { "Aap" })
    wait(rpc, [[return vim.fn.complete_info({'selected'}).selected == 0]], "wide replacement menu")
    rpc:lua([[vim.api.nvim_select_popupmenu_item(0,true,false,{})]])
    wait(rpc, "return vim.api.nvim_get_current_line() == " .. string.format("%q", result), "projected preview")
    rpc:request("nvim_input", { "<CR>" })
    wait(rpc, [[return vim.fn.pumvisible() == 0]], "accepted wide edit")
    rpc:request("nvim_input", { "<Esc>j$." })
    wait(
      rpc,
      "return vim.api.nvim_buf_get_lines(0,1,2,false)[1] == " .. string.format("%q", result),
      "dot repeat applies the complete edit at the second namespace"
    )
  end)
end

t:test("wide snippets project their preview without trimming the accepted snippet", function()
  local rpc = editor({
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
  rpc:request("nvim_input", { "Aap" })
  wait(rpc, [[return vim.fn.complete_info({'selected'}).selected == 0]], "wide snippet menu")
  t.assert_eq(
    "alpha_value",
    rpc:lua([[return vim.fn.complete_info({'items'}).items[1].word]]),
    "projected snippet prefix"
  )
  rpc:lua([[vim.api.nvim_select_popupmenu_item(0,true,false,{})]])
  wait(rpc, [[return vim.api.nvim_get_current_line() == 'obj.alpha_value']], "native snippet preview")
  rpc:request("nvim_input", { "<CR>" })
  wait(
    rpc,
    [[return vim.snippet.active() and vim.api.nvim_get_current_line() == 'obj.alpha_value']],
    "the original wide snippet still owns its placeholder"
  )
  rpc:request("nvim_input", { "replacement<Tab>" })
  wait(rpc, [[return vim.api.nvim_get_current_line() == 'obj.alpha_replacement']], "placeholder editing")
end)

t:run()
