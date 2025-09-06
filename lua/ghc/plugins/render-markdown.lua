return {
  "render-markdown.nvim",
  ft = eve.filetype.get_markdown_filetypes(),
  cmd = { "RenderMarkdown" },
  opts = {
    anti_conceal = {
      disabled_modes = { "n" },
      ignore = {
        bullet = true, -- render bullet in insert mode
        head_border = true,
        head_background = true,
      },
    },
    bullet = {
      icons = { "", "", "", "⟡" },
    },
    callout = {
      abstract = {
        raw = "[!ABSTRACT]",
        rendered = "󰯂 Abstract",
        highlight = "RenderMarkdownInfo",
        category = "obsidian",
      },
      summary = {
        raw = "[!SUMMARY]",
        rendered = "󰯂 Summary",
        highlight = "RenderMarkdownInfo",
        category = "obsidian",
      },
      tldr = { raw = "[!TLDR]", rendered = "󰦩 Tldr", highlight = "RenderMarkdownInfo", category = "obsidian" },
      failure = {
        raw = "[!FAILURE]",
        rendered = " Failure",
        highlight = "RenderMarkdownError",
        category = "obsidian",
      },
      fail = { raw = "[!FAIL]", rendered = " Fail", highlight = "RenderMarkdownError", category = "obsidian" },
      missing = {
        raw = "[!MISSING]",
        rendered = " Missing",
        highlight = "RenderMarkdownError",
        category = "obsidian",
      },
      attention = {
        raw = "[!ATTENTION]",
        rendered = " Attention",
        highlight = "RenderMarkdownWarn",
        category = "obsidian",
      },
      warning = { raw = "[!WARNING]", rendered = " Warning", highlight = "RenderMarkdownWarn", category = "github" },
      danger = { raw = "[!DANGER]", rendered = " Danger", highlight = "RenderMarkdownError", category = "obsidian" },
      error = { raw = "[!ERROR]", rendered = " Error", highlight = "RenderMarkdownError", category = "obsidian" },
      bug = { raw = "[!BUG]", rendered = " Bug", highlight = "RenderMarkdownError", category = "obsidian" },
      quote = { raw = "[!QUOTE]", rendered = " Quote", highlight = "RenderMarkdownQuote", category = "obsidian" },
      cite = { raw = "[!CITE]", rendered = " Cite", highlight = "RenderMarkdownQuote", category = "obsidian" },
      todo = { raw = "[!TODO]", rendered = " Todo", highlight = "RenderMarkdownInfo", category = "obsidian" },
      wip = { raw = "[!WIP]", rendered = "󰦖 WIP", highlight = "RenderMarkdownHint", category = "obsidian" },
      done = { raw = "[!DONE]", rendered = " Done", highlight = "RenderMarkdownSuccess", category = "obsidian" },
    },
    checkbox = {
      unchecked = {
        icon = "󰄱",
        highlight = "RenderMarkdownCodeFallback",
        scope_highlight = "RenderMarkdownCodeFallback",
      },
      checked = {
        icon = "󰄵",
        highlight = "RenderMarkdownUnchecked",
        scope_highlight = "RenderMarkdownUnchecked",
      },
      custom = {
        question = {
          raw = "[?]",
          rendered = "",
          highlight = "RenderMarkdownError",
          scope_highlight = "RenderMarkdownError",
        },
        todo = {
          raw = "[>]",
          rendered = "󰦖",
          highlight = "RenderMarkdownInfo",
          scope_highlight = "RenderMarkdownInfo",
        },
        canceled = {
          raw = "[-]",
          rendered = "",
          highlight = "RenderMarkdownCodeFallback",
          scope_highlight = "@text.strike",
        },
        important = {
          raw = "[!]",
          rendered = "",
          highlight = "RenderMarkdownWarn",
          scope_highlight = "RenderMarkdownWarn",
        },
        favorite = {
          raw = "[~]",
          rendered = "",
          highlight = "RenderMarkdownMath",
          scope_highlight = "RenderMarkdownMath",
        },
      },
    },
    code = {
      border = "thin",
      conceal_delimiters = false,
      highlight_inline = "RenderMarkdownCodeInfo",
      language_icon = true,
      language_name = true,
      left_pad = 1,
      min_width = 80,
      position = "right",
      render_modes = true,
      right_pad = 1,
      sign = false,
      width = "block",
    },
    completions = {
      blink = { enabled = true },
      lsp = { enabled = false },
    },
    file_types = eve.filetype.get_markdown_filetypes(),
    heading = {
      icons = {},
      border = true,
      render_modes = true, -- keep rendering while inserting
    },
    link = {
      wiki = { icon = " ", highlight = "RenderMarkdownWikiLink", scope_highlight = "RenderMarkdownWikiLink" },
      image = " ",
      custom = {
        github = { pattern = "github", icon = " " },
        gitlab = { pattern = "gitlab", icon = "󰮠 " },
        youtube = { pattern = "youtube", icon = " " },
        cern = { pattern = "cern.ch", icon = " " },
      },
      hyperlink = " ",
    },
    pipe_table = {
      alignment_indicator = "─",
      border = { "╭", "┬", "╮", "├", "┼", "┤", "╰", "┴", "╯", "│", "─" },
    },
    quote = {
      repeat_linebreak = true,
    },
    sign = { enabled = false },
    -- https://github.com/MeanderingProgrammer/render-markdown.nvim/issues/509
    win_options = { concealcursor = { rendered = "nvc" } },
  },
  config = function(_, opts)
    require("fml.dressing.plugin").mock_miniicons()

    local plugin = require("render-markdown")
    plugin.setup(opts)

    std.fn.observe({ eve.context.plugin.render_markdown }, function()
      local flag = eve.context.plugin.render_markdown:snapshot() ---@type boolean
      if flag then
        plugin.enable()
      else
        plugin.disable()
      end
    end, false)
  end,
}
