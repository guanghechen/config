eve.lsp_action.setup()
eve.lsp_action.register({
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
    local word = lint.word_under_cursor()
    if word == nil then
      return
    end

    if not lint.has_cspell_diagnostic(ctx.bufnr, ctx.lnum) then
      return
    end

    return {
      {
        title = string.format('cspell: add "%s" to dictionary', word),
        kind = "quickfix",
        source = "cspell",
        execute = function()
          lint.spellcheck_register()
        end,
      },
    }
  end,
})
