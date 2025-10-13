return {
  name = "sidekick.nvim",
  event = "VeryLazy",
  opts = {
    cli = {
      mux = {
        backend = "tmux",
        enabled = true,
      },
      prompts = {
        changes = "Can you review my changes?",
        diagnostics = "Can you help me fix the diagnostics in {file}?\n{diagnostics}",
        diagnostics_all = "Can you help me fix these diagnostics?\n{diagnostics_all}",
        document = "Add documentation to {function|line}",
        explain = "Explain {this}",
        fix = "Can you fix {this}?",
        optimize = "How can {this} be optimized?",
        review = "Can you review {file} for any issues or improvements?",
        tests = "Can you write tests for {this}?",
        buffers = "{buffers}",
        file = "{file}",
        line = "{line}",
        position = "{position}",
        quickfix = "{quickfix}",
        selection = "{selection}",
        ["function"] = "{function}",
        class = "{class}",
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
        return vim.b[bufnr].sidekick_nes ~= false
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
        external_attached = "󰖩 ",
        external_started = "󰖪 ",
        terminal_attached = " ",
        terminal_started = " ",
      },
    },
  },
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
    {
      "<leader>;",
      function()
        require("sidekick.cli").toggle({ filter = { installed = true } })
      end,
      desc = "sidekick: toggle",
      mode = { "n", "v" },
    },
    {
      "<leader>ac",
      function()
        require("sidekick.cli").toggle({ name = "claude", focus = true })
      end,
      desc = "sidekick: toggle claude",
      mode = { "n", "v" },
    },
    {
      "<leader>as",
      function()
        require("sidekick.cli").select({ filter = { installed = true } })
      end,
      desc = "sidekick: select cli",
      mode = { "n", "v" },
    },
    {
      "<leader>ad",
      function()
        require("sidekick.cli").close()
      end,
      desc = "sidekick: detach a cli session",
      mode = { "n", "v" },
    },
    {
      "<leader>at",
      function()
        require("sidekick.cli").send({ msg = "{this}" })
      end,
      desc = "sidekick: send this",
      mode = { "n", "v" },
    },
    {
      "<leader>af",
      function()
        require("sidekick.cli").send({ msg = "{file}" })
      end,
      desc = "sidekick: send file",
      mode = { "n", "v" },
    },
    {
      "<leader>av",
      function()
        require("sidekick.cli").send({ msg = "{selection}" })
      end,
      desc = "sidekick: send visual selection",
      mode = { "x" },
    },
    {
      "<leader>ap",
      function()
        require("sidekick.cli").prompt()
      end,
      desc = "sidekick: select prompt",
      mode = { "n", "x" },
    },
  },
}
