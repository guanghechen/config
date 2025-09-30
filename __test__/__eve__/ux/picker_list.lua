---@diagnostic disable: invisible
require("plenary.reload").reload_module("std.collection.observable")
require("plenary.reload").reload_module("std.collection.history")
require("plenary.reload").reload_module("eve.ux.picker.composer.basic")
require("plenary.reload").reload_module("eve.ux.picker.composer.list")
require("plenary.reload").reload_module("eve.ux.picker.finder")
require("plenary.reload").reload_module("eve.ux.picker.result")
require("plenary.reload").reload_module("eve.ux.picker.preview")
require("plenary.reload").reload_module("eve.ux.retriever")

local name = "test-list-picker"
local finder_input = std.Observable.from_value("")
local finder_input_history = std.InputHistory.new({
  name = name,
  capacity = 5,
  input = finder_input,
})
local o_flag_fuzzy = std.Observable.from_value(true)
local o_flag_regex = std.Observable.from_value(false)
local o_flag_case_sensitive = std.Observable.from_value(false)
local o_flag_test_mode = std.Observable.from_value(1)

local test_items = {
  {
    uuid = "item-1",
    text = "First Item - Hello World",
    text_lower = "first item - hello world",
    highlights = {
      { coll = 0, colr = 5, hlname = "DiagnosticInfo" },
      { coll = 13, colr = 18, hlname = "String" },
      { coll = 19, colr = 24, hlname = "Keyword" },
    },
  },
  {
    uuid = "item-2",
    text = "Second Item - Lua Programming",
    text_lower = "second item - lua programming",
    highlights = {
      { coll = 0, colr = 6, hlname = "Number" },
      { coll = 14, colr = 17, hlname = "Function" },
      { coll = 18, colr = 29, hlname = "Type" },
    },
  },
  {
    uuid = "item-3",
    text = "Third Item - Neovim Configuration",
    text_lower = "third item - neovim configuration",
    highlights = {
      { coll = 0, colr = 5, hlname = "Special" },
      { coll = 13, colr = 19, hlname = "Title" },
      { coll = 20, colr = 33, hlname = "Constant" },
    },
  },
  {
    uuid = "item-4",
    text = "Fourth Item - Test Data",
    text_lower = "fourth item - test data",
    highlights = {
      { coll = 0, colr = 6, hlname = "PreProc" },
      { coll = 14, colr = 18, hlname = "DiagnosticWarn" },
      { coll = 19, colr = 23, hlname = "Identifier" },
    },
  },
  {
    uuid = "item-5",
    text = "Fifth Item - Example Content",
    text_lower = "fifth item - example content",
    highlights = {
      { coll = 0, colr = 5, hlname = "Comment" },
      { coll = 13, colr = 20, hlname = "Variable" },
      { coll = 21, colr = 28, hlname = "StorageClass" },
    },
  },
}

local picker
picker = eve.ux.picker.ListComposer.new({
  uuid = "__test__eve_ux_picker_list__",
  name = name,
  permanent = false,
  title = "Test List Picker",
  height = 0.80,
  width = 0.85,
  finder_input = finder_input,
  finder_input_history = finder_input_history,
  flag_fuzzy = o_flag_fuzzy,
  flag_regex = o_flag_regex,
  flag_case_sensitive = o_flag_case_sensitive,
  flags_start_index = 0,
  flags_prepend = {
    {
      desc = "test-list: settings",
      callback = function()
        print("Settings clicked!")
      end,
      snapshot = function()
        return eve.icon.symbols.setting, "picker_flag_purple"
      end,
    },
  },
  flags_append = {
    {
      desc = "test-list: test mode",
      callback = function()
        local mode = o_flag_test_mode:snapshot()
        local next_mode = mode % 3 + 1
        o_flag_test_mode:next(next_mode)
      end,
      snapshot = function()
        local mode = o_flag_test_mode:snapshot()
        return string.format("T%d", mode), "picker_flag_orange"
      end,
    },
  },
  keymaps_common = {
    {
      modes = { "i", "n", "v" },
      key = "<c-q>",
      desc = "test-list: quit",
      callback = function()
        picker:close()
      end,
    },
  },

  keymaps_result = {
    {
      modes = { "n" },
      key = "dd",
      desc = "test-list: delete item",
      callback = function()
        local lnum = picker.result.lnum_current:snapshot()
        local uuid = picker._retriever:retrieve_uuid(lnum)
        if uuid then
          print(string.format("Would delete item: %s", uuid))
        end
      end,
    },
  },
  ---@type eve.ux.picker.composer.list.IRenderResult
  render_result = function(_, bufnr, itemmap, matches)
    local lines = {} ---@type string[]
    local uuids = {} ---@type string[]
    local prefix = "📋 " ---@type string
    local offset = #prefix

    for _, match in ipairs(matches) do
      local item = itemmap[match.uuid]
      lines[#lines + 1] = prefix .. item.text
      uuids[#uuids + 1] = item.uuid
    end
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

    local nsnr_content = eve.var.nsnr.picker_result ---@type integer
    local nsnr_matches = eve.var.nsnr.picker_matches ---@type integer
    for lnum, match in ipairs(matches) do
      local row = lnum - 1 ---@type integer
      local item = itemmap[match.uuid]

      if item and item.highlights then
        for _, hl in ipairs(item.highlights) do
          vim.hl.range(
            bufnr,
            nsnr_content,
            hl.hlname,
            { row, hl.coll + offset },
            { row, hl.colr + offset },
            { priority = 10 }
          )
        end
      end

      if match.matches then
        for _, m in ipairs(match.matches) do
          vim.hl.range(
            bufnr,
            nsnr_matches,
            "f_pk_matches",
            { row, m.l + offset },
            { row, m.r + offset },
            { priority = 30 }
          )
        end
      end
    end

    ---@type eve.ux.picker.composer.list.IRenderResultData
    local result = { uuids = uuids }
    return result
  end,
  render_preview = function(self, bufnr)
    local lnum = self.result.lnum_current:snapshot()
    local uuid = self._retriever:retrieve_uuid(lnum)

    if not uuid then
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "",
        "                🔍  NO SELECTION",
        "",
        "            ╭─────────────────────╮",
        "            │ ◦ Use ↑/↓ or j/k    │",
        "            │   to navigate       │",
        "            │                     │",
        "            │ ◦ Press <Enter>     │",
        "            │   to select         │",
        "            │                     │",
        "            │ ◦ Press <Esc> or    │",
        "            │   <C-q> to exit     │",
        "            ╰─────────────────────╯",
        "",
        "              Navigate to start →",
        "",
      })

      local nsnr = vim.api.nvim_create_namespace("modern_preview_empty")
      -- Main title
      vim.hl.range(bufnr, nsnr, "@text.title", { 1, 16 }, { 1, 31 })
      vim.hl.range(bufnr, nsnr, "@text.uri", { 1, 16 }, { 1, 19 })

      -- Box borders
      for i = 3, 12 do
        vim.hl.range(bufnr, nsnr, "FloatBorder", { i, 12 }, { i, 35 })
      end

      -- Instructions
      vim.hl.range(bufnr, nsnr, "@markup.list", { 4, 18 }, { 4, 19 })
      vim.hl.range(bufnr, nsnr, "@markup.list", { 7, 18 }, { 7, 19 })
      vim.hl.range(bufnr, nsnr, "@markup.list", { 10, 18 }, { 10, 19 })
      vim.hl.range(bufnr, nsnr, "Comment", { 14, 14 }, { 14, 32 })

      return {
        cursorline = false,
        number = false,
        title = "✨ Item Preview",
        wrap = false,
        lnum = 1,
      }
    end

    local item = self._itemmap[uuid]
    if not item then
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "",
        "                ⚠️  ITEM ERROR",
        "",
        "            ╭─────────────────────╮",
        "            │  Selected item not  │",
        "            │  found in itemmap   │",
        "            │                     │",
        "            │  UUID: " .. string.format("%-11s", (uuid or "unknown"):sub(1, 11)) .. " │",
        "            ╰─────────────────────╯",
        "",
      })

      local nsnr = vim.api.nvim_create_namespace("modern_preview_error")
      vim.hl.range(bufnr, nsnr, "DiagnosticError", { 1, 16 }, { 1, 30 })
      vim.hl.range(bufnr, nsnr, "FloatBorder", { 3, 12 }, { 8, 35 })
      vim.hl.range(bufnr, nsnr, "Identifier", { 7, 23 }, { 7, 28 })
      vim.hl.range(bufnr, nsnr, "String", { 7, 29 }, { 7, 29 + #((uuid or "unknown"):sub(1, 11)) })

      return {
        cursorline = false,
        number = false,
        title = "⚠️ Preview Error",
        wrap = false,
        lnum = 1,
      }
    end

    -- Modern card-style layout
    local lines = {
      "",
      "    ╭─── ✨ ITEM DETAILS ───────────────────╮",
      "    │                                      │",
    }

    -- Item identity section
    local uuid_display = #item.uuid > 30 and (item.uuid:sub(1, 27) .. "...") or item.uuid
    lines[#lines + 1] = string.format("    │  🆔  %-32s │", uuid_display)

    local text_display = #item.text > 30 and (item.text:sub(1, 27) .. "...") or item.text
    lines[#lines + 1] = string.format("    │  📄  %-32s │", text_display)

    lines[#lines + 1] = "    │                                      │"

    -- Highlights section
    if item.highlights and #item.highlights > 0 then
      lines[#lines + 1] = "    ├─── 🎨 SYNTAX HIGHLIGHTS ─────────────┤"
      lines[#lines + 1] = "    │                                      │"

      for i, highlight in ipairs(item.highlights) do
        local hl_text = item.text:sub(highlight.coll + 1, highlight.colr)
        local hl_display = #hl_text > 18 and (hl_text:sub(1, 15) .. "...") or hl_text
        local pos_info = string.format("[%d:%d]", highlight.coll, highlight.colr)

        lines[#lines + 1] = string.format('    │  %d.  "%-18s" %7s   │', i, hl_display, pos_info)
        lines[#lines + 1] = string.format("    │      %-30s │", highlight.hlname)
        if i < #item.highlights then
          lines[#lines + 1] = "    │      ·  ·  ·  ·  ·  ·  ·  ·  ·  ·    │"
        end
      end
    else
      lines[#lines + 1] = "    ├─── 🎨 SYNTAX HIGHLIGHTS ─────────────┤"
      lines[#lines + 1] = "    │                                      │"
      lines[#lines + 1] = "    │      ∅  No highlights defined        │"
    end

    lines[#lines + 1] = "    │                                      │"

    -- Status section with modern indicators
    lines[#lines + 1] = "    ├─── ⚙️  SEARCH OPTIONS ───────────────┤"
    lines[#lines + 1] = "    │                                      │"

    local fuzzy_icon = self.flag_fuzzy:snapshot() and "🟢" or "🔴"
    local regex_icon = self.flag_regex:snapshot() and "🟢" or "🔴"
    local case_icon = self.flag_case_sensitive:snapshot() and "🟢" or "🔴"

    lines[#lines + 1] =
      string.format("    │  %s Fuzzy    %s Regex    %s Case   │", fuzzy_icon, regex_icon, case_icon)
    lines[#lines + 1] = "    │                                      │"

    -- Test mode indicator
    local mode_icon = "🧪"
    lines[#lines + 1] =
      string.format("    │  %s Test Mode: %d                   │", mode_icon, o_flag_test_mode:snapshot())

    lines[#lines + 1] = "    │                                      │"
    lines[#lines + 1] =
      "    ╰──────────────────────────────────────╯"
    lines[#lines + 1] = ""

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

    -- Modern highlighting scheme
    local nsnr = vim.api.nvim_create_namespace("modern_preview_card")

    -- Header styling
    vim.hl.range(bufnr, nsnr, "@text.title", { 1, 4 }, { 1, 41 })
    vim.hl.range(bufnr, nsnr, "Special", { 1, 9 }, { 1, 12 })
    vim.hl.range(bufnr, nsnr, "@text.title", { 1, 13 }, { 1, 25 })

    -- Card borders
    for i = 1, #lines do
      if lines[i]:match("^    [╭├╰]") or lines[i]:match("^    │") then
        if lines[i]:find("ITEM DETAILS") then
          vim.hl.range(bufnr, nsnr, "@text.title", { i - 1, 0 }, { i - 1, -1 })
        elseif lines[i]:find("SYNTAX HIGHLIGHTS") then
          vim.hl.range(bufnr, nsnr, "@markup.heading", { i - 1, 0 }, { i - 1, -1 })
        elseif lines[i]:find("SEARCH OPTIONS") then
          vim.hl.range(bufnr, nsnr, "@keyword", { i - 1, 0 }, { i - 1, -1 })
        else
          vim.hl.range(bufnr, nsnr, "FloatBorder", { i - 1, 0 }, { i - 1, -1 })
        end
      end
    end

    -- Content highlighting
    for i, line in ipairs(lines) do
      -- UUID and text content
      if line:find("🆔") then
        vim.hl.range(bufnr, nsnr, "@constant", { i - 1, 6 }, { i - 1, 8 })
        vim.hl.range(bufnr, nsnr, "Identifier", { i - 1, 10 }, { i - 1, 10 + #uuid_display })
      elseif line:find("📄") then
        vim.hl.range(bufnr, nsnr, "@string", { i - 1, 6 }, { i - 1, 8 })
        vim.hl.range(bufnr, nsnr, "String", { i - 1, 10 }, { i - 1, 10 + #text_display })
      end

      -- Highlight entries
      if line:match("│  %d+%.") then
        -- Number
        vim.hl.range(bufnr, nsnr, "Number", { i - 1, 7 }, { i - 1, 9 })
        -- Quoted text
        local quote_start = line:find('"')
        local quote_end = line:find('"', quote_start + 1)
        if quote_start and quote_end then
          vim.hl.range(bufnr, nsnr, "@string", { i - 1, quote_start - 1 }, { i - 1, quote_end })
        end
        -- Position info
        local pos_start = line:find("%[%d+:%d+%]")
        if pos_start then
          vim.hl.range(
            bufnr,
            nsnr,
            "Comment",
            { i - 1, pos_start - 1 },
            { i - 1, pos_start + line:match("%[%d+:%d+%]"):len() - 1 }
          )
        end
      elseif line:match("│      [%w_]+") and not line:find("·") and not line:find("∅") then
        -- Highlight group names
        local hlname_start = line:find("[%w_]+", 10)
        local hlname = line:match("([%w_]+)", 10)
        if hlname_start and hlname then
          vim.hl.range(bufnr, nsnr, "@type", { i - 1, hlname_start - 1 }, { i - 1, hlname_start + #hlname - 1 })
        end
      elseif line:find("·") then
        -- Separator dots
        vim.hl.range(bufnr, nsnr, "Comment", { i - 1, 0 }, { i - 1, -1 })
      elseif line:find("∅") then
        -- Empty state
        vim.hl.range(bufnr, nsnr, "Comment", { i - 1, 0 }, { i - 1, -1 })
      end

      -- Status indicators
      if line:find("🟢") or line:find("🔴") then
        vim.hl.range(bufnr, nsnr, "Normal", { i - 1, 0 }, { i - 1, -1 })
        -- Highlight the status words
        local fuzzy_pos = line:find("Fuzzy")
        local regex_pos = line:find("Regex")
        local case_pos = line:find("Case")

        if fuzzy_pos then
          vim.hl.range(
            bufnr,
            nsnr,
            self.flag_fuzzy:snapshot() and "@string.special" or "Comment",
            { i - 1, fuzzy_pos - 1 },
            { i - 1, fuzzy_pos + 4 }
          )
        end
        if regex_pos then
          vim.hl.range(
            bufnr,
            nsnr,
            self.flag_regex:snapshot() and "@string.special" or "Comment",
            { i - 1, regex_pos - 1 },
            { i - 1, regex_pos + 4 }
          )
        end
        if case_pos then
          vim.hl.range(
            bufnr,
            nsnr,
            self.flag_case_sensitive:snapshot() and "@string.special" or "Comment",
            { i - 1, case_pos - 1 },
            { i - 1, case_pos + 3 }
          )
        end
      end

      if line:find("Test Mode") then
        vim.hl.range(bufnr, nsnr, "@keyword", { i - 1, 6 }, { i - 1, 8 })
        vim.hl.range(bufnr, nsnr, "@type", { i - 1, 10 }, { i - 1, 19 })
        vim.hl.range(bufnr, nsnr, "Number", { i - 1, 21 }, { i - 1, 22 })
      end
    end

    return {
      cursorline = true,
      number = false,
      title = string.format("✨ %s", item.uuid:sub(1, 20) .. (#item.uuid > 20 and "…" or "")),
      wrap = false,
      whitespaces = false,
      lnum = 4, -- Focus on the UUID line
    }
  end,

  on_confirm = function(self, item)
    if item then
      print(string.format("Selected item: %s - %s", item.uuid, item.text))
    else
      print("No item selected or cancelled")
    end
    self:close()
  end,
  on_focused = function(self)
    print(string.format("Picker focused: %s", self.title))
  end,
  on_closed = function(self)
    print(string.format("Picker closed: %s", self.title))
  end,
  on_refresh = function(_, force)
    print(string.format("Picker refresh requested (force: %s)", tostring(force)))
  end,
})

o_flag_test_mode:subscribe(
  std.Subscriber.new({
    on_next = function(mode)
      local items = {}
      local uuid_current = nil
      local uuid_present = nil
      if mode == 1 then
        items = vim.deepcopy(test_items)
        items[#items + 1] = {
          uuid = "item-dynamic-1",
          text = "🚀 Dynamic Item - API Endpoint",
          text_lower = "🚀 dynamic item - api endpoint",
          highlights = {
            { coll = 3, colr = 10, hlname = "DiagnosticOk" },
            { coll = 18, colr = 21, hlname = "Error" },
            { coll = 22, colr = 30, hlname = "WarningMsg" },
          },
        }
        items[#items + 1] = {
          uuid = "item-dynamic-2",
          text = "📝 Documentation - README.md",
          text_lower = "📝 documentation - readme.md",
          highlights = {
            { coll = 3, colr = 16, hlname = "Directory" },
            { coll = 19, colr = 28, hlname = "NonText" },
          },
        }
        uuid_current = "item-1"
        uuid_present = "item-3"
      elseif mode == 2 then
        for _, item in ipairs(test_items) do
          if item.text:find("Item") then
            local enhanced_item = vim.deepcopy(item)
            local item_start = item.text:find("Item") - 1
            enhanced_item.highlights[#enhanced_item.highlights + 1] = {
              coll = item_start,
              colr = item_start + 4,
              hlname = "IncSearch",
            }
            items[#items + 1] = enhanced_item
          end
        end
        uuid_current = "item-2"
        uuid_present = "item-4"
      else
        local complex_item = vim.deepcopy(test_items[1])
        complex_item.text = "🔧 Complex Highlighting Example - Multiple Overlays"
        complex_item.text_lower = "🔧 complex highlighting example - multiple overlays"
        complex_item.highlights = {
          { coll = 0, colr = 51, hlname = "Title" },
          { coll = 3, colr = 10, hlname = "Function" },
          { coll = 11, colr = 23, hlname = "Keyword" },
          { coll = 24, colr = 31, hlname = "String" },
          { coll = 34, colr = 42, hlname = "Type" },
          { coll = 43, colr = 51, hlname = "Special" },
          { coll = 15, colr = 27, hlname = "Search" },
        }
        items = { complex_item }
        uuid_current = "item-1"
        uuid_present = "item-1"
      end
      picker:reset_data({
        items = items,
        uuid_current = uuid_current,
        uuid_present = uuid_present,
      })
      picker:mark_result_dirty()
      picker:focus()
    end,
  }),
  false
)

vim.schedule(function()
  o_flag_test_mode:next(1)
end)
