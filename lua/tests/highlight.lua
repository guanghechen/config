local function test_compile_highlights()
  local theme = ghc.ui.Theme
    .new()
    :register("KyokuyaReplaceInvisible", { fg = "none", bg = "none" })
    :register("KyokuyaReplaceOptName", { fg = "blue", bg = "none", bold = true })
    :register("KyokuyaReplaceOptReplacePattern", { fg = "diff_add_hl", bg = "none" })
    :register("KyokuyaReplaceOptSearchPattern", { fg = "diff_delete_hl", bg = "none" })
    :register("KyokuyaReplaceOptValue", { fg = "yellow", bg = "none" })
    :register("KyokuyaReplaceFilepath", { fg = "blue", bg = "none" })
    :register("KyokuyaReplaceFlag", { fg = "white", bg = "grey" })
    :register("KyokuyaReplaceFlagEnabled", { fg = "black", bg = "baby_pink" })
    :register("KyokuyaReplaceFence", { fg = "grey", bg = "none" })
    :register("KyokuyaReplaceTextDeleted", { fg = "diff_delete_hl", strikethrough = true })
    :register("KyokuyaReplaceTextAdded", { fg = "diff_add_hl", bg = "none" })
    :register("KyokuyaReplaceUsage", { fg = "grey_fg2", bg = "none" })

  local scheme = require("ghc.context.theme.scheme.darken") ---@type ghc.types.ui.theme.IScheme
  local hlgroup_strs = {} ---@type string[]
  for hlname, hlgroup in pairs(theme:resolve(scheme)) do
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
