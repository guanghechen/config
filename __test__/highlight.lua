local function test_compile_highlights()
  local scheme = require("ghc.ui.theme.scheme.darken") ---@type fml.types.ui.theme.IScheme
  local c = scheme.colors
  local hlgroup_map = {
    f_sr_invisible = { fg = "none", bg = "none" },
    f_sr_opt_name = { fg = c.blue, bg = "none", bold = true },
    f_sr_opt_replace_pattern = { fg = c.diff_add_word, bg = "none" },
    f_sr_opt_search_pattern = { fg = c.diff_del_word, bg = "none" },
    f_sr_opt_value = { fg = c.yellow, bg = "none" },
    f_sr_filepath = { fg = c.blue, bg = "none" },
    f_sr_flag = { fg = c.white, bg = "grey" },
    f_sr_flag_enabled = { fg = c.black, bg = c.baby_pink },
    f_sr_result_fence = { fg = c.grey, bg = "none" },
    f_sr_text_deleted = { fg = c.diff_del_word, strikethrough = true },
    f_sr_text_added = { fg = c.diff_add_word, bg = "none" },
    f_sr_usage = { fg = c.grey_fg2, bg = "none" },
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

  local file = io.open(eve.path.cwd() .. "/a.lua", "wb")
  if file then
    --file:write(loadstring(lines)())
    file:write(lines)
    file:close()
  end
end

test_compile_highlights()
--dofile(eve.path.cwd() .. "/a.lua")
