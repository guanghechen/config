---@see https://github.com/MeanderingProgrammer/render-markdown.nvim/tree/6e0e8902dac70fecbdd8ce557d142062a621ec38

return {
  "render-markdown.nvim",
  ft = eve.filetype.get_markdown_filetypes(),
  cmd = { "RenderMarkdown" },
  opts = {
    debounce = 200,
    file_types = eve.filetype.get_markdown_filetypes(),
    log_level = "error",
    log_runtime = false,
    max_file_size = 1,
    nested = true,
    preset = "none",
    render_modes = { "n", "c", "t" },
    restart_highlighter = false,

    ------------------------------------------------------------------------------------------------

    anti_conceal = {
      disabled_modes = { "n" },
      ignore = {
        bullet = true, -- render bullet in insert mode
        head_border = true,
        head_background = true,
      },
    },
    completions = {
      blink = { enabled = false },
      lsp = { enabled = false },
    },
    win_options = {
      -- https://github.com/MeanderingProgrammer/render-markdown.nvim/issues/509
      concealcursor = { rendered = "nvc" },
    },

    ------------------------------------------------------------------------------------------------

    bullet = {
      highlight = "f_md_bullet",
      icons = { "", "", "", "⟡" },
    },
    callout = {
      -- github callouts
      caution = {
        raw = "[!CAUTION]",
        rendered = "󰳦 Caution",
        highlight = "f_md_callout_error",
        category = "github",
      },
      important = {
        raw = "[!IMPORTANT]",
        rendered = "󰅾 Important",
        highlight = "f_md_callout_hint",
        category = "github",
      },
      note = {
        raw = "[!NOTE]",
        rendered = "󰋽 Note",
        highlight = "f_md_callout_info",
        category = "github",
      },
      tip = {
        raw = "[!TIP]",
        rendered = "󰌶 Tip",
        highlight = "f_md_callout_success",
        category = "github",
      },
      warning = {
        raw = "[!WARNING]",
        rendered = " Warning",
        highlight = "f_md_callout_warn",
        category = "github",
      },
      -- obsidian callouts
      abstract = {
        raw = "[!ABSTRACT]",
        rendered = "󰯂 Abstract",
        highlight = "f_md_callout_info",
        category = "obsidian",
      },
      attention = {
        raw = "[!ATTENTION]",
        rendered = " Attention",
        highlight = "f_md_callout_warn",
        category = "obsidian",
      },
      bug = {
        raw = "[!BUG]",
        rendered = "󰨰 Bug",
        highlight = "f_md_callout_error",
        category = "obsidian",
      },
      check = {
        raw = "[!CHECK]",
        rendered = "󰄬 Check",
        highlight = "f_md_callout_success",
        category = "obsidian",
      },
      cite = {
        raw = "[!CITE]",
        rendered = "󱆨 Cite",
        highlight = "f_md_callout_quote",
        category = "obsidian",
      },
      danger = {
        raw = "[!DANGER]",
        rendered = "󱐌 Danger",
        highlight = "f_md_callout_error",
        category = "obsidian",
      },
      done = {
        raw = "[!DONE]",
        rendered = " Done",
        highlight = "f_md_callout_success",
        category = "obsidian",
      },
      error = {
        raw = "[!ERROR]",
        rendered = "󱐌 Error",
        highlight = "f_md_callout_error",
        category = "obsidian",
      },
      example = {
        raw = "[!EXAMPLE]",
        rendered = "󰉹 Example",
        highlight = "f_md_callout_hint",
        category = "obsidian",
      },
      faq = {
        raw = "[!FAQ]",
        rendered = "󰘥 Faq",
        highlight = "f_md_callout_warn",
        category = "obsidian",
      },
      fail = {
        raw = "[!FAIL]",
        rendered = "󰅖 Fail",
        highlight = "f_md_callout_error",
        category = "obsidian",
      },
      failure = {
        raw = "[!FAILURE]",
        rendered = "󰅖 Failure",
        highlight = "f_md_callout_error",
        category = "obsidian",
      },
      help = {
        raw = "[!HELP]",
        rendered = "󰘥 Help",
        highlight = "f_md_callout_warn",
        category = "obsidian",
      },
      hint = {
        raw = "[!HINT]",
        rendered = "󰌶 Hint",
        highlight = "f_md_callout_success",
        category = "obsidian",
      },
      info = {
        raw = "[!INFO]",
        rendered = "󰋽 Info",
        highlight = "f_md_callout_info",
        category = "obsidian",
      },
      missing = {
        raw = "[!MISSING]",
        rendered = "󰅖 Missing",
        highlight = "f_md_callout_error",
        category = "obsidian",
      },
      question = {
        raw = "[!QUESTION]",
        rendered = "󰘥 Question",
        highlight = "f_md_callout_warn",
        category = "obsidian",
      },
      quote = {
        raw = "[!QUOTE]",
        rendered = "󱆨 Quote",
        highlight = "f_md_callout_quote",
        category = "obsidian",
      },
      success = {
        raw = "[!SUCCESS]",
        rendered = "󰄬 Success",
        highlight = "f_md_callout_success",
        category = "obsidian",
      },
      summary = {
        raw = "[!SUMMARY]",
        rendered = "󰯂 Summary",
        highlight = "f_md_callout_info",
        category = "obsidian",
      },
      tldr = {
        raw = "[!TLDR]",
        rendered = "󰦩 Tldr",
        highlight = "f_md_callout_info",
        category = "obsidian",
      },
      todo = {
        raw = "[!TODO]",
        rendered = " Todo",
        highlight = "f_md_callout_info",
        category = "obsidian",
      },
      wip = {
        raw = "[!WIP]",
        rendered = "󰦖 WIP",
        highlight = "f_md_callout_progress",
        category = "obsidian",
      },
    },
    checkbox = {
      left_pad = 0,
      unchecked = {
        icon = " ",
        highlight = "f_md_task_open",
        scope_highlight = "f_md_task_open",
      },
      checked = {
        icon = "󰄲 ",
        highlight = "f_md_task_done",
        scope_highlight = "f_md_task_done",
      },
      custom = {
        question = {
          raw = "[?]",
          rendered = " ",
          highlight = "f_md_task_question",
          scope_highlight = "f_md_task_question",
        },
        todo = {
          raw = "[>]",
          rendered = "󰦖 ",
          highlight = "f_md_task_next",
          scope_highlight = "f_md_task_next",
        },
        cancelled = {
          raw = "[-]",
          rendered = " ",
          highlight = "f_md_task_cancelled",
          scope_highlight = "f_md_task_cancelled_text",
        },
        important = {
          raw = "[!]",
          rendered = " ",
          highlight = "f_md_task_important",
          scope_highlight = "f_md_task_important",
        },
        favorite = {
          raw = "[~]",
          rendered = " ",
          highlight = "f_md_task_favorite",
          scope_highlight = "f_md_task_favorite",
        },
      },
    },
    code = {
      border = "thin",
      conceal_delimiters = false,
      highlight = "f_md_code",
      highlight_border = "f_md_code_border",
      highlight_fallback = "f_md_code_fallback",
      highlight_info = "f_md_code_header",
      highlight_inline = "f_md_code_inline",
      language = true,
      language_icon = true,
      language_info = true,
      language_name = true,
      language_pad = 0,
      left_pad = 1,
      min_width = 80,
      position = "right",
      right_pad = 1,
      sign = false,
      width = "block",
    },
    dash = {
      highlight = "f_md_dash",
      left_margin = 0,
      width = "full",
    },
    heading = {
      atx = true,
      border = true,
      icons = {},
      setext = true,
      backgrounds = {
        "f_md_heading_h1_bg",
        "f_md_heading_h2_bg",
        "f_md_heading_h3_bg",
        "f_md_heading_h4_bg",
        "f_md_heading_h5_bg",
        "f_md_heading_h6_bg",
      },
      foregrounds = {
        "f_md_heading_h1",
        "f_md_heading_h2",
        "f_md_heading_h3",
        "f_md_heading_h4",
        "f_md_heading_h5",
        "f_md_heading_h6",
      },
      custom = {
        wip = { pattern = "WIP", icon = "🚧", background = "DiagnosticWarn" },
      },
    },
    ---@diagnostic disable-next-line: unused-local
    ignore = function(bufnr)
      return false
    end,
    inline_highlight = {
      enabled = true,
      highlight = "f_md_text_inline_highlight",
    },
    indent = {
      icon = "▎",
      priority = 0,
    },
    latex = {
      enabled = false,
    },
    link = {
      email = "󰇮 ",
      highlight = "f_md_link",
      hyperlink = " ",
      image = " ",
      wiki = {
        icon = " ",
        body = function(ctx)
          if ctx.alias and ctx.alias ~= "" then
            return ctx.alias
          end
          local destination = (ctx.destination or ""):gsub("^%s*(.-)%s*$", "%1")
          if destination == "" then
            return nil
          end
          local leaf = destination:match("([^/\\]+)$") or destination
          return leaf:gsub("%.%w+$", "")
        end,
        highlight = "f_md_link_wiki",
        scope_highlight = "f_md_link_wiki",
      },
      custom = {
        github = { pattern = "github%.com", icon = " ", kind = "pattern", priority = 90 },
        gitlab = { pattern = "gitlab%.com", icon = "󰮠 ", kind = "pattern", priority = 80 },
        youtube = { pattern = "youtube.com", icon = " ", kind = "suffix", priority = 70 },
        cern = { pattern = "cern.ch", icon = " ", kind = "suffix", priority = 60 },
      },
    },
    paragraph = {
      enabled = true,
      left_margin = 0,
      indent = 0,
      min_width = 80,
    },
    pipe_table = {
      enabled = true,
      border_enabled = true,
      border_virtual = true,
      cell = "padded",
      preset = "round",
      filler = "f_md_table_filler",
      head = "f_md_table_head",
      row = "f_md_table_row",
      style = "full",
    },
    quote = {
      repeat_linebreak = true,
      highlight = "f_md_quote",
    },
    sign = {
      enabled = false,
    },
    yaml = {
      enabled = true,
    },
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
