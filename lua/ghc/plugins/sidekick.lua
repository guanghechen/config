---@class ghc.plugins.sidekick.actions
local actions = {
  select_cli = function()
    require("sidekick.cli").select({ filter = { installed = true } })
  end,
  detach_cli = function()
    require("sidekick.cli").close()
  end,
  submit_buffer = function()
    local bufnr = vim.api.nvim_get_current_buf() ---@type integer
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]
    local content = table.concat(lines, "\n")
    require("sidekick.cli").send({ msg = content, render = false, focus = true, submit = true })
  end,
  submit_selection = function()
    local text = eve.buf.retrieve_selected_text() ---@type string
    require("sidekick.cli").send({ msg = text, render = false, focus = true, submit = true })
  end,
  send_buffer = function()
    local bufnr = vim.api.nvim_get_current_buf() ---@type integer
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]
    local content = table.concat(lines, "\n")
    require("sidekick.cli").send({ msg = content, render = false })
  end,
  send_selection = function()
    local text = eve.buf.retrieve_selected_text() ---@type string
    require("sidekick.cli").send({ msg = text, render = false })
  end,
  send_this = function()
    require("sidekick.cli").send({ msg = "{this}" })
  end,
  send_file = function()
    require("sidekick.cli").send({ msg = "{file}" })
  end,
  select_prompt = function()
    require("sidekick.cli").prompt()
  end,
}

---@type std.t.IKeymap[]
local keymaps = {
  {
    modes = { "n", "v" },
    key = "<leader>aa",
    desc = "sidekick: select cli",
    callback = actions.select_cli,
  },
  {
    modes = { "n", "v" },
    key = "<leader>ad",
    desc = "sidekick: detach a cli session",
    callback = actions.detach_cli,
  },
  {
    modes = { "n" },
    key = "<leader>ax",
    desc = "sidekick: submit with the buffer content",
    callback = actions.submit_buffer,
  },
  {
    modes = { "v" },
    key = "<leader>ax",
    desc = "sidekick: submit with selection",
    callback = actions.submit_selection,
  },
  {
    modes = { "n" },
    key = "<leader>as",
    desc = "sidekick: send the buffer content",
    callback = actions.send_buffer,
  },
  {
    modes = { "v" },
    key = "<leader>as",
    desc = "sidekick: send the selection",
    callback = actions.send_selection,
  },
  {
    modes = { "n", "v" },
    key = "<leader>at",
    desc = "sidekick: send this",
    callback = actions.send_this,
  },
  {
    modes = { "n", "v" },
    key = "<leader>af",
    desc = "sidekick: send file",
    callback = actions.send_file,
  },
  {
    modes = { "n", "x" },
    key = "<leader>ap",
    desc = "sidekick: select prompt",
    callback = actions.select_prompt,
  },
}
eve.nvim.bindkeys(keymaps, { noremap = true, silent = true })

return {
  name = "sidekick.nvim",
  event = "VeryLazy",
  keys = {
    {
      "<Tab>",
      function()
        -- if there is a next edit, jump to it, otherwise apply it if any
        if not require("sidekick").nes_jump_or_apply() then
          return "<Tab>" -- fallback to normal tab
        end
      end,
      expr = true,
      desc = "sidekick: goto/apply next edit suggestion",
    },
  },
  opts = {
    cli = {
      mux = {
        backend = "tmux",
        enabled = not std.env.IS_WIN,
        create = "terminal",
      },
      prompts = {
        code = function(ctx)
          local bufnr = ctx.buf ---@type integer
          local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]
          local content = table.concat(lines, "\n")
          return content
        end,
      },
      tools = {
        claude = {
          cmd = { "claude", "--dangerously-skip-permissions" },
          env = {
            CLAUDE_CONFIG_DIR = vim.env.CLAUDE_CONFIG_DIR,
          },
        },
        codex = {
          env = {
            CODEX_HOME = vim.env.CODEX_HOME,
          },
        },
      },
      win = {
        wo = {
          number = false,
          wrap = true,
        },
        bo = {},
        layout = "right",
        split = {
          width = 100,
          height = vim.o.lines,
        },
        keys = {
          nav_left = { "<M-h>", "nav_left", expr = true, desc = "navigate to the left window" },
          nav_down = { "<M-j>", "nav_down", expr = true, desc = "navigate to the below window" },
          nav_up = { "<M-k>", "nav_up", expr = true, desc = "navigate to the above window" },
          nav_right = { "<M-l>", "nav_right", expr = true, desc = "navigate to the right window" },
        },
        nav = function(direction)
          require("fml.action.win.focus").navigate(direction)
        end,
      },
    },
    jump = {
      jumplist = true, -- add an entry to the jumplist
    },
    nes = {
      enabled = function(bufnr)
        return eve.context.flight.ai_nes:snapshot() and vim.b[bufnr].sidekick_nes ~= false
      end,
      debounce = 300,
      trigger = {
        events = { "InsertLeave", "TextChanged", "User SidekickNesDone" },
      },
      clear = {
        events = { "TextChangedI", "InsertEnter" },
        esc = true, -- clear next edit suggestions when pressing <Esc>
      },
      ---@class sidekick.diff.Opts
      ---@field inline? "words"|"chars"|false Enable inline diffs
      diff = {
        inline = "words",
      },
    },
    signs = {
      enabled = true,
      icon = eve.icon.app.Copilot .. " ",
    },
    ui = {
      icons = {
        attached = " ",
        started = " ",
        installed = " ",
        missing = " ",
        external_attached = eve.icon.status.attached .. " ",
        external_started = eve.icon.status.detached .. " ",
        terminal_attached = " ",
        terminal_started = " ",
      },
    },
  },
}
