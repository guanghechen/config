local function test_compile_highlights()
  local scheme = fml.api.highlight.Scheme
    .new()
    :register("kyokuya_invisible", { fg = "none", bg = "none" })
    :register("kyokuya_replace_cfg_name", { fg = "blue", bg = "none", bold = true })
    :register("kyokuya_replace_cfg_replace_pattern", { fg = "diff_add_hl", bg = "none" })
    :register("kyokuya_replace_cfg_search_pattern", { fg = "diff_delete_hl", bg = "none" })
    :register("kyokuya_replace_cfg_value", { fg = "yellow", bg = "none" })
    :register("kyokuya_replace_filepath", { fg = "blue", bg = "none" })
    :register("kyokuya_replace_flag", { fg = "white", bg = "grey" })
    :register("kyokuya_replace_flag_enabled", { fg = "black", bg = "baby_pink" })
    :register("kyokuya_replace_result_fence", { fg = "grey", bg = "none" })
    :register("kyokuya_replace_text_deleted", { fg = "diff_delete_hl", strikethrough = true })
    :register("kyokuya_replace_text_added", { fg = "diff_add_hl", bg = "none" })
    :register("kyokuya_replace_usage", { fg = "grey_fg2", bg = "none" })

  local palette = require("kyokuya.theme.palette.darken")
  local hlgroup_strs = {} ---@type string[]
  for hlname, hlgroup in pairs(scheme:resolve(palette)) do
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
