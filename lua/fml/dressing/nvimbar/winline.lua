local __module_name__ = "fml.dressing.nvimbar.winline"

local states = require("fml.dressing.nvimbar.state")
local c = require("fml.dressing.nvimbar.components")

local txt = eve.nvim.txt
local position = "f_wl" ---@type eve.ux.nvimbar.Position

---@param winnr                         integer|nil
---@param callback                      fun(err: string|false|nil): nil
---@return nil
local function locate_symbols(winnr, callback)
  if winnr == nil or not eve.win.is_valid(winnr) then
    callback(false)
    return
  end

  ---! Make the request to the LSP server
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  if
    vim.b[bufnr][eve.var.Names.WINLINE_DISABLED]
    or not eve.lsp.has_support_method(bufnr, "textDocument/documentSymbol")
  then
    callback(false)
    return
  end

  local ok, cmp = pcall(require, "blink.cmp")
  if ok and cmp.is_visible() then
    callback(false)
    return
  end

  local callback_called = false ---@type boolean

  ---@param err                         string|false|nil
  ---@return nil
  local function safe_callback(err)
    if not callback_called then
      callback_called = true
      callback(err)
      return
    end
  end

  local cursor = vim.api.nvim_win_get_cursor(winnr) or { 1, 1 } ---@type integer[]
  local row = cursor[1] or 1 ---@type integer
  local col = cursor[2] or 1 ---@type integer

  -- Handle the lsp request response.
  ---@param err                         any|nil
  ---@param symbols                     any[]
  ---@return nil
  local function handler(err, symbols)
    if not vim.api.nvim_win_is_valid(winnr) then
      safe_callback(false)
      return
    end

    if err then
      if type(err) == "table" then
        if err.message == "Content modified." then
          safe_callback(false)
          return
        end

        if err.message == "trying to get AST for non-added document" then
          if vim.api.nvim_buf_is_valid(bufnr) then
            vim.b[bufnr][eve.var.Names.WINLINE_DISABLED] = true
          end
        end
      end
      if eve.status.suppress_warning:snapshot() then
        safe_callback(false)
        return
      end

      eve.reporter.error({
        from = __module_name__,
        subject = "locate_symbols",
        message = "Failed to request document symbols",
        details = { err = err, result = symbols, bufnr = bufnr, winnr = winnr },
      })
      safe_callback(err.message or "Failed to request document symbols")
      return
    end

    local winline = states.winline_map[winnr] ---@type fml.dressing.nvimbar.state.IWinline
    if winline == nil or winline.lsp_symbols == nil or type(symbols) ~= "table" then
      safe_callback(false)
      return
    end

    local cursor_pos = { line = row - 1, character = col }
    local symbol_path = eve.lsp.find_symbol_path(cursor_pos, symbols)
    local pieces = winline.lsp_symbols ---@type fml.dressing.nvimbar.state.ILspSymbol[]

    local N = #pieces ---@type integer
    local k = 1 ---@type integer
    if symbol_path then
      for _, symbol in ipairs(symbol_path) do
        local kind = vim.lsp.protocol.SymbolKind[symbol.kind]
        local name = symbol.name
        local pos = symbol.range and symbol.range.start or symbol.location.range.start
        ---@type fml.dressing.nvimbar.state.ILspSymbol
        local piece = {
          kind = kind,
          name = name,
          row = pos.line + 1,
          col = pos.character + 1,
        }

        pieces[k] = piece
        k = k + 1
      end
    end
    for i = N, k, -1 do
      pieces[i] = nil
    end
    safe_callback()
  end

  eve.std.timer.set_timeout(function()
    safe_callback("Request document symbols timeout")
  end, 10000)

  ---! Make the request to the LSP server
  vim.lsp.buf_request(
    bufnr,
    "textDocument/documentSymbol",
    { textDocument = vim.lsp.util.make_text_document_params() },
    handler
  )
end

---@param winnr                         integer
---@param source                        "sourcefile"|"neotree"
---@return eve.ux.INvimbar|nil
local function resolve_nvimbar(winnr, source)
  local winline_map = states.winline_map ---@type table<integer, fml.dressing.nvimbar.state.IWinline>
  local winline = winline_map[winnr] ---@type fml.dressing.nvimbar.state.IWinline|nil
  if winline == nil or winline.nvimbar:is_disposed() then
    local nvimbar = nil ---@type eve.ux.INvimbar|nil
    nvimbar = eve.ux.Nvimbar.new({
      name = "winline_" .. winnr,
      comp_sep = "",
      comp_sep_hlname = position .. "_bg",
      comp_sep_hlname_active = position .. "_bg",
      render_delay = 128,
      silent = function()
        local devmode = eve.state.flight.devmode:snapshot() ---@type boolean
        return not devmode
      end,
      get_max_width = function()
        if vim.api.nvim_win_is_valid(winnr) then
          return vim.api.nvim_win_get_width(winnr)
        end
        return 0
      end,
      get_preset_context = function()
        return { winnr = winnr }
      end,
      is_active = function(context)
        local winnr_cur = vim.api.nvim_get_current_win() ---@type integer
        return winnr_cur > 0 and winnr_cur == context.winnr
      end,
      pre_task = function(callback)
        if nvimbar == nil or nvimbar:is_disposed() then
          return
        end

        if not vim.api.nvim_win_is_valid(winnr) then
          nvimbar:dispose()
          nvimbar = nil
          return
        end

        if source == "sourcefile" then
          -- Quick rerender the nvimbar before the pre_task done to make the ui quick refresh.
          local result = nvimbar:render_immediately()
          vim.wo[winnr].winbar = result

          locate_symbols(winnr, function(err)
            if err == nil then
              callback()
              return
            end

            if err == false then
              callback()
            else
              callback(err)
            end
          end)
          return
        end

        callback()
      end,
      trigger_rerender = function()
        if nvimbar == nil or nvimbar:is_disposed() then
          return
        end

        if not vim.api.nvim_win_is_valid(winnr) then
          nvimbar:dispose()
          nvimbar = nil
          return
        end

        local result = nvimbar:snapshot() ---@type string
        vim.wo[winnr].winbar = result
      end,
      validate = function()
        if not vim.api.nvim_win_is_valid(winnr) then
          return "The window is not valid, winnr=" .. winnr .. "."
        end
      end,
    })

    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    winline = winline or { bufnr = bufnr, nvimbar = nvimbar } ---@type fml.dressing.nvimbar.state.IWinline

    winline.nvimbar = nvimbar
    winline_map[winnr] = winline

    if source == "sourcefile" then
      nvimbar
        ---
        :place("left", c.dirpath(position), 95)
        :place("left", c.filename(position), 100)
        :place("left", c.lsp_symbols(position), 90)
        ---
        :place("center", c.debug_render_count(position), 100)
      ---
      -- :place("right", c.dirpath_prominent(position), 100)

      winline.lsp_symbols = winline.lsp_symbols or {}
    elseif source == "neotree" then
      local is_floating = eve.win.is_float(winnr) ---@type boolean
      nvimbar:place("center", c.neotree(position, is_floating and "float" or "left"), 100)
    else
    end
  end

  local nvimbar = winline.nvimbar ---@type eve.ux.INvimbar
  if winline.lsp_symbols ~= nil then
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    if winline.bufnr ~= bufnr then
      winline.bufnr = bufnr
      winline.lsp_symbols = {}
      vim.wo[winnr].winbar = nvimbar:render_immediately()
    end
  end
  return nvimbar
end

---@param winnr                         integer|nil
---@return nil
local function render(winnr)
  if winnr == nil or not eve.win.is_valid(winnr) then
    return
  end

  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local filetype = vim.bo[bufnr].filetype ---@type string
  if eve.filetype.has_external_winline(filetype) then
    return
  end

  if filetype == eve.filetype.NEOTREE then
    if vim.o.showtabline == 0 or eve.win.is_float(winnr) then
      local nvimbar = resolve_nvimbar(winnr, "neotree") ---@type eve.ux.INvimbar|nil
      if nvimbar ~= nil then
        nvimbar:render()
      end
    else
      vim.wo[winnr].winbar = nil
    end
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  if filepath:sub(1, 11) == "diffview://" then
    local should_show_winline = filepath:sub(1, 19) ~= "diffview:///panels/" ---@type boolean
    if should_show_winline then
      local text = filepath:sub(12) ---@type string
      if text:sub(1, #eve.env.HOME_NVIM_CONFIG) == eve.env.HOME_NVIM_CONFIG then
        text = "<NVIM_HOME>" .. text:sub(#eve.env.HOME_NVIM_CONFIG + 1)
      end
      local winbar = "diffview://" .. text
      vim.wo[winnr].winbar = txt(winbar, "f_wl_text")
    end
    return
  end
  if filepath:sub(1, 11) == "gitsigns://" then
    local text = filepath:sub(12) ---@type string
    if text:sub(1, #eve.env.HOME_NVIM_CONFIG) == eve.env.HOME_NVIM_CONFIG then
      text = "<NVIM_HOME>" .. text:sub(#eve.env.HOME_NVIM_CONFIG + 1)
    end
    local winbar = "gitsigns://" .. text
    vim.wo[winnr].winbar = txt(winbar, "f_wl_text")
    return
  end

  local buftype = vim.bo[bufnr].buftype ---@type string
  if buftype == "nofile" then
    return
  end

  if not eve.win.is_sourcefile(winnr) then
    return
  end

  local nvimbar = resolve_nvimbar(winnr, "sourcefile") ---@type eve.ux.INvimbar|nil
  if nvimbar ~= nil then
    nvimbar:render()
    return
  end

  if eve.filetype.is_sourcefile(filetype) then
    vim.wo[winnr].winbar = txt(filepath, "f_wl_text")
    return
  end
end

eve.status.dirty_winline_nr:subscribe(
  eve.std.Subscriber.new({
    on_next = function(winnr, winnr_prev)
      render(winnr)
      if winnr_prev ~= winnr then
        render(winnr_prev)
      end
    end,
  }),
  true
)
