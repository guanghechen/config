---@param text                          string
---@return string
---@return std.t.IHighlightInline[]
local function generate_highlights(text)
  local matches = {} ---@type {pos: integer, end_pos: integer, content: string, group: string}[]

  for start_pos, content, group, end_pos in text:gmatch("()%[([^%]]+)%]%(([^%)]+)%)()") do
    matches[#matches + 1] = { pos = start_pos, end_pos = end_pos, content = content, group = group }
  end

  local explicit_positions = {} ---@type table<integer, boolean>
  for i = 1, #matches do
    explicit_positions[matches[i].pos] = true
  end

  for start_pos, content, end_pos in text:gmatch("()%[([^%]]+)%]()") do
    if not explicit_positions[start_pos] then
      matches[#matches + 1] = { pos = start_pos, end_pos = end_pos, content = content, group = "SnacksPickerLabel" }
    end
  end

  for start_pos, content, end_pos in text:gmatch("()%{([^}]+)%}()") do
    matches[#matches + 1] = {
      pos = start_pos,
      end_pos = end_pos,
      content = "{" .. content .. "}",
      group = "SnacksPickerFile",
    }
  end

  table.sort(matches, function(a, b)
    return a.pos < b.pos
  end)

  local line_text = "" ---@type string
  local highlights = {} ---@type std.t.IHighlightInline[]
  local last_pos = 1 ---@type integer
  local current_col = 0 ---@type integer

  for i = 1, #matches do
    local match = matches[i]
    if match.pos > last_pos then
      local plain = text:sub(last_pos, match.pos - 1)
      line_text = line_text .. plain
      current_col = current_col + vim.api.nvim_strwidth(plain)
    end

    line_text = line_text .. match.content
    highlights[#highlights + 1] = {
      coll = current_col,
      colr = current_col + vim.api.nvim_strwidth(match.content),
      hlname = match.group,
    }
    current_col = current_col + vim.api.nvim_strwidth(match.content)
    last_pos = match.end_pos
  end

  if last_pos <= #text then
    line_text = line_text .. text:sub(last_pos)
  end

  return line_text, highlights
end

---@param items                         any[]
---@param opts                          fml.dressing.select.IOptions
---@return eve.ux.picker.composer.list.IResetData
---@return integer
---@return eve.ux.picker.composer.list.IRenderResult|nil
---@return eve.ux.picker.composer.list.IRenderPreview|nil
local function snacks_provider(items, opts)
  local format_item = opts.format_item or std.fn.identity ---@type fun(item): string|nil
  local width = 0 ---@type integer
  local select_items = {} ---@type fml.dressing.select.IItem[]

  for i = 1, #items do
    local item = items[i]
    local raw_text = format_item(item) or (type(item) == "table" and item.text) or tostring(item) ---@type string
    raw_text = raw_text:gsub("\n", "\\n")

    local text, highlights = generate_highlights(raw_text) ---@type string, std.t.IHighlightInline[]
    local text_len = #text ---@type integer
    if text_len > width then
      width = text_len
    end

    select_items[#select_items + 1] = {
      uuid = item.name or oxi.fn.md5(text),
      text = text,
      text_lower = text:lower(),
      data = { original_item = item },
      highlights = highlights,
    }
  end

  local render_preview ---@type eve.ux.picker.composer.list.IRenderPreview|nil

  ---@diagnostic disable-next-line: undefined-field
  if opts.picker and opts.picker.preview == "preview" then
    render_preview = function(composer, bufnr)
      local lnum_current = composer.result.lnum_current:snapshot() ---@type integer
      if lnum_current < 1 then
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "No item selected" })
        return { cursorline = false, number = false, title = "Preview", wrap = false }
      end

      local item = composer:retrieve(lnum_current) ---@type fml.dressing.select.IItem|nil
      if not item then
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "No item selected" })
        return { cursorline = false, number = false, title = "Preview", wrap = false }
      end

      local original_item = item.data.original_item ---@type any
      local preview = original_item.preview ---@type {text: string, extmarks: any[]}|nil
      if not preview then
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "No preview available" })
        return { cursorline = false, number = false, title = item.text, wrap = false }
      end

      local lines = vim.split(preview.text or "", "\n", { plain = true }) ---@type string[]
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

      if preview.extmarks then
        local nsnr = eve.var.nsnr.picker_preview ---@type integer
        local line_count = #lines ---@type integer
        for i = 1, #preview.extmarks do
          local extmark = preview.extmarks[i]
          local row = (extmark.row or extmark[4]) - 1 ---@type integer
          local coll = extmark.col or extmark[1] ---@type integer|nil
          local colr = extmark.end_col or extmark[2] ---@type integer|nil
          local hlname = extmark.hl_group or extmark[3] ---@type string|nil

          if row >= 0 and row < line_count and coll and colr and hlname then
            vim.hl.range(bufnr, nsnr, hlname, { row, coll }, { row, colr }, { priority = 10 })
          end
        end
      end

      return {
        cursorline = true,
        number = true,
        title = " " .. (original_item.name or item.text) .. " ",
        wrap = true,
      }
    end
  end

  local prefer_width = render_preview and 160 or 100 ---@type integer
  width = math.min(math.max(width, prefer_width), math.floor(vim.o.columns * 0.9)) ---@type integer

  return { items = select_items }, width, nil, render_preview
end

return snacks_provider
