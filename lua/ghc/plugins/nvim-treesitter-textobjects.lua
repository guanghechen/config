---! https://github.com/nvim-treesitter/nvim-treesitter-textobjects
return {
  name = "nvim-treesitter-textobjects",
  event = "VeryLazy",
  opts = {
    move = {
      enable = true,
      set_jumps = true,
    },
    select = {
      lookahead = true,
      selection_modes = {
        ["@parameter.outer"] = "v",
        ["@function.outer"] = "V",
        ["@class.outer"] = "<c-v>",
      },
      include_surrounding_whitespace = false,
    },
  },
  config = function(_, opts)
    require("nvim-treesitter-textobjects").setup(opts)

    local select = require("nvim-treesitter-textobjects.select")
    local move = require("nvim-treesitter-textobjects.move")

    ---@param key string
    ---@param query string|string[]
    ---@return string
    local function make_move_desc(key, query)
      local queries = type(query) == "table" and query or { query } ---@type string[]
      local parts = {}
      for _, q in ipairs(queries) do
        local part = q:gsub("@", ""):gsub("%..*", "")
        part = part:sub(1, 1):upper() .. part:sub(2)
        parts[#parts + 1] = part
      end
      local prefix = key:sub(1, 1) == "[" and "Prev " or "Next "
      local suffix = key:sub(2, 2) == key:sub(2, 2):upper() and " End" or " Start"
      return prefix .. table.concat(parts, " or ") .. suffix
    end

    ---@alias ITreeTextobjectMoveSpec { key: string, query: string|string[], source?: string, desc?: string, modes?: string[] }

    ---@type table<string, ITreeTextobjectMoveSpec[]>
    local move_specs = {
      goto_next_start = {
        { key = "]a", query = "@parameter.inner" },
        { key = "]b", query = "@block.outer" },
        { key = "]c", query = "@class.outer" },
        { key = "]f", query = "@function.outer" },
        { key = "]s", query = "@local.scope", source = "locals", desc = "Next Scope Start" },
        { key = "]z", query = "@fold", source = "folds", desc = "Next Fold Start" },
      },
      goto_next_end = {
        { key = "]A", query = "@parameter.inner" },
        { key = "]C", query = "@class.outer" },
        { key = "]F", query = "@function.outer" },
      },
      goto_previous_start = {
        { key = "[a", query = "@parameter.inner" },
        { key = "[b", query = "@block.outer" },
        { key = "[c", query = "@class.outer" },
        { key = "[f", query = "@function.outer" },
        { key = "[s", query = "@local.scope", source = "locals", desc = "Prev Scope Start" },
        { key = "[z", query = "@fold", source = "folds", desc = "Prev Fold Start" },
      },
      goto_previous_end = {
        { key = "[A", query = "@parameter.inner" },
        { key = "[C", query = "@class.outer" },
        { key = "[F", query = "@function.outer" },
      },
    }

    ---@type std.t.IKeymap[]
    local keymaps = {}

    ---@type { key: string, query: string, source?: string, desc: string, modes?: string[] }[]
    local select_specs = {
      { key = "af", query = "@function.outer", desc = "Select Function Outer" },
      { key = "if", query = "@function.inner", desc = "Select Function Inner" },
      { key = "ac", query = "@class.outer", desc = "Select Class Outer" },
      { key = "ic", query = "@class.inner", desc = "Select Class Inner" },
      { key = "as", query = "@local.scope", source = "locals", desc = "Select Scope" },
    }

    for _, spec in ipairs(select_specs) do
      local key = spec.key
      local query = spec.query
      local source = spec.source or "textobjects"
      keymaps[#keymaps + 1] = {
        modes = spec.modes or { "x", "o" },
        key = key,
        desc = spec.desc,
        callback = function()
          select.select_textobject(query, source)
        end,
      }
    end

    for method, specs in pairs(move_specs) do
      for _, spec in ipairs(specs) do
        local key = spec.key
        local query = spec.query
        local source = spec.source or "textobjects"
        local desc = spec.desc or make_move_desc(key, query)
        keymaps[#keymaps + 1] = {
          modes = spec.modes or { "n", "x", "o" },
          key = key,
          desc = desc,
          callback = function()
            move[method](query, source)
          end,
        }
      end
    end

    eve.nvim.bindkeys(keymaps, {})
  end,
}
