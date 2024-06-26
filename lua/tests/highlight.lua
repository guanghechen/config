local function test_compile_highlights()
  local scheme = require("ghc.ui.theme.scheme.darken") ---@type fml.types.ui.theme.IScheme
  local c = scheme.colors
  local hlgroup_map = {
    GhcReplaceInvisible = { fg = "none", bg = "none" },
    GhcReplaceOptName = { fg = c.blue, bg = "none", bold = true },
    GhcReplaceOptReplacePattern = { fg = c.diff_add_hl, bg = "none" },
    GhcReplaceOptSearchPattern = { fg = c.diff_delete_hl, bg = "none" },
    GhcReplaceOptValue = { fg = c.yellow, bg = "none" },
    GhcReplaceFilepath = { fg = c.blue, bg = "none" },
    GhcReplaceFlag = { fg = c.white, bg = "grey" },
    GhcReplaceFlagEnabled = { fg = c.black, bg = c.baby_pink },
    GhcReplaceFence = { fg = c.grey, bg = "none" },
    GhcReplaceTextDeleted = { fg = c.diff_delete_hl, strikethrough = true },
    GhcReplaceTextAdded = { fg = c.diff_add_hl, bg = "none" },
    GhcReplaceUsage = { fg = c.grey_fg2, bg = "none" },
  }

  local hlgroup_strs = {} ---@type string[]
  for hlname, hlgroup in pairs(hlgroup_map) do
    local hlgroup_fields = {} ---@type string[]
    for key, value in pairs(hlgroup) do
      local value_type = type(value) ---@type string
      local value_stringified = (value_type == "boolean" or value_type == "number") and tostring(value)
        or '"' .. value .. '"'
      local field = key .. "=" .. value_stringified ---@type string
      table.insert(hlgroup_fields, field)
    end
    local hlgroup_str = hlname .. "={" .. table.concat(hlgroup_fields, ",") .. "}"
    table.insert(hlgroup_strs, hlgroup_str)
  end

  local lines = "return string.dump(function()\nlocal hls={"
    .. table.concat(hlgroup_strs, ",")
    .. "}\n"
    .. "for k, v in pairs(hls) do\n"
    .. "vim.api.nvim_set_hl(0,k,v)\n"
    .. "end\nend, true)\n"

  local file = io.open(fml.path.cwd() .. "/a.lua", "wb")
  if file then
    --file:write(loadstring(lines)())
    file:write(lines)
    file:close()
  end
end

test_compile_highlights()
--dofile(fml.path.cwd() .. "/a.lua")
