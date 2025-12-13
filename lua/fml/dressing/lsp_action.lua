era.lsp_action.setup()
era.lsp_action.register({
  id = "cspell-add-word",
  source = "cspell",
  handler = function(ctx)
    if ctx.context and ctx.context.only then
      local offer = false ---@type boolean
      for _, requested_kind in ipairs(ctx.context.only) do
        if requested_kind == "quickfix" or vim.startswith(requested_kind, "quickfix.") then
          offer = true
          break
        end
      end
      if not offer then
        return
      end
    end

    local lint = require("fml.action.lint") ---@type fml.action.lint
    local word_context = lint.word_context(ctx.bufnr, ctx.lnum, ctx.cursor.col)
    if word_context == nil then
      return
    end

    local diagnostic = lint.find_cspell_diagnostic(ctx.bufnr, ctx.lnum, word_context)
    if diagnostic == nil then
      return
    end

    local actions = {} ---@type era.t.ILspActionProviderAction[]

    local suggestions = lint.cspell_suggestions_from_diagnostic(diagnostic) ---@type string[]
    if #suggestions > 0 then
      local seen = {} ---@type table<string, boolean>
      local limit = 5 ---@type integer
      local collected = 0 ---@type integer
      for _, raw_suggestion in ipairs(suggestions) do
        local preview = lint.preview_cspell_suggestion(word_context, raw_suggestion)
        if #preview > 0 and preview ~= word_context.text and not seen[preview] then
          seen[preview] = true
          actions[#actions + 1] = {
            title = string.format('cspell: replace "%s" with "%s"', word_context.text, preview),
            kind = "quickfix",
            source = "cspell",
            execute = function()
              lint.apply_cspell_suggestion(ctx.bufnr, ctx.lnum, ctx.cursor.col, raw_suggestion)
            end,
          }
          collected = collected + 1
          if collected >= limit then
            break
          end
        end
      end
    end

    actions[#actions + 1] = {
      title = string.format('cspell: add "%s" to dictionary', word_context.normalized),
      kind = "quickfix",
      source = "cspell",
      execute = function()
        lint.spellcheck_register()
      end,
    }

    return actions
  end,
})
