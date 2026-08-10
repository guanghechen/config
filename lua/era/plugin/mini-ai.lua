---@see https://github.com/nvim-mini/mini.ai

-- taken from MiniExtra.gen_ai_spec.buffer
local function ai_buffer(ai_type)
  local start_line, end_line = 1, vim.fn.line("$")
  if ai_type == "i" then
    -- Skip first and last blank lines for `i` textobject
    local first_nonblank, last_nonblank = vim.fn.nextnonblank(start_line), vim.fn.prevnonblank(end_line)
    -- Do nothing for buffer with all blanks
    if first_nonblank == 0 or last_nonblank == 0 then
      return { from = { line = start_line, col = 1 } }
    end
    start_line, end_line = first_nonblank, last_nonblank
  end

  local to_col = math.max(vim.fn.getline(end_line):len(), 1)
  return { from = { line = start_line, col = 1 }, to = { line = end_line, col = to_col } }
end

local function ai_splitline(ai_type)
  return era.m.splitline.ai_textobject(ai_type)
end

local function ai_hunk()
  return era.m.git.hunk.ai_textobject()
end

return {
  name = "mini.ai",
  event = "VeryLazy",
  opts = function()
    local ai = require("mini.ai")
    return {
      n_lines = 500,
      search_method = "cover_or_next",
      silent = false,
      custom_textobjects = {
        o = ai.gen_spec.treesitter({ -- code block
          a = { "@block.outer", "@conditional.outer", "@loop.outer" },
          i = { "@block.inner", "@conditional.inner", "@loop.inner" },
        }),
        f = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }), -- function
        h = ai_hunk, -- unstaged Git hunk
        c = ai.gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }), -- class
        t = { "<([%p%w]-)%f[^<%w][^<>]->.-</%1>", "^<.->().*()</[^/]->$" }, -- tags
        d = { "%f[%d]%d+" }, -- digits
        e = { -- Word with case
          { "%u[%l%d]+%f[^%l%d]", "%f[%S][%l%d]+%f[^%l%d]", "%f[%P][%l%d]+%f[^%l%d]", "^[%l%d]+%f[^%l%d]" },
          "^().*()$",
        },
        g = ai_buffer, -- buffer
        m = ai.gen_spec.treesitter({ a = "@comment.outer", i = "@comment.inner" }), --- comment
        n = { "%-?%d+%.?%d*" }, --- number with natural decimal point
        u = ai.gen_spec.function_call(), -- u for "Usage"
        U = ai.gen_spec.function_call({ name_pattern = "[%w_]" }), -- without dot in function name
        s = ai_splitline, -- splitline block
      },
      mappings = {
        around = "a",
        inside = "i",
        around_next = "", --- Disable for lsp selection
        inside_next = "", --- Disable for lsp selection
        around_last = "", --- Disable for lsp selection
        inside_last = "", --- Disable for lsp selection
        goto_left = "g[",
        goto_right = "g]",
      },
    }
  end,
  config = function(_, opts)
    require("mini.ai").setup(opts)

    --- Register all text objects with which-key
    vim.schedule(function()
      local objects = {
        { " ", desc = "whitespace" },
        { '"', desc = '" string' },
        { "'", desc = "' string" },
        { "(", desc = "() block" },
        { ")", desc = "() block with ws" },
        { "<", desc = "<> block" },
        { ">", desc = "<> block with ws" },
        { "?", desc = "user prompt" },
        { "U", desc = "use/call without dot" },
        { "[", desc = "[] block" },
        { "]", desc = "[] block with ws" },
        { "`", desc = "` string" },
        { "a", desc = "argument" },
        { "b", desc = ")]} block" },
        { "c", desc = "class" },
        { "d", desc = "digit(s)" },
        { "e", desc = "CamelCase / snake_case" },
        { "f", desc = "function" },
        { "g", desc = "entire file" },
        { "h", desc = "unstaged Git hunk" },
        { "i", desc = "indent" },
        { "m", desc = "comment" },
        { "n", desc = "number" },
        { "o", desc = "block, conditional, loop" },
        { "q", desc = "quote `\"'" },
        { "s", desc = "splitline block" },
        { "t", desc = "tag" },
        { "u", desc = "use/call" },
        { "{", desc = "{} block" },
        { "}", desc = "{} with ws" },
      }

      local ret = { mode = { "o", "x" } }
      local mappings = vim.tbl_extend("force", {}, opts.mappings) ---@type table<string, string>
      mappings.goto_left = nil
      mappings.goto_right = nil

      for name, prefix in pairs(mappings) do
        if prefix ~= nil and prefix ~= "" then
          name = name:gsub("^around_", ""):gsub("^inside_", "")
          ret[#ret + 1] = { prefix, group = name }
          for _, obj in ipairs(objects) do
            local desc = obj.desc
            if string.sub(prefix, 1, 1) == "i" then
              desc = desc:gsub(" with ws", "")
            end
            ret[#ret + 1] = { prefix .. obj[1], desc = desc }
          end
        end
      end
      era.m.wk.add(ret, { notify = false })
    end)
  end,
}
