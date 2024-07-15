---@class ghc.command.replace.main
local M = require("ghc.command.replace.main.mod")

---Render the search/replace options
---@param state                         ghc.command.replace.state
---@return nil
function M.internal_render_cfg(state)
  ---@param key     ghc.enums.command.replace.StateKey
  ---@param title   string
  ---@param hlvalue string
  ---@param flags   ?{ icon: string, enabled: boolean }[]
  local function print_cfg_field(key, title, hlvalue, flags)
    local title_width = #title ---@type integer
    local cfg_name_len = M.CFG_NAME_LEN ---@type integer
    local invisible_width = cfg_name_len - title_width ---@type integer
    local left = fml.string.pad_start(title, cfg_name_len, " ") .. ": " ---@type string
    local value_start_pos = cfg_name_len + 2 ---@type integer

    ---@type fml.types.ui.printer.ILineHighlight[]
    local highlights = {
      { cstart = 0, cend = invisible_width, hlname = "f_sr_invisible" },
      { cstart = invisible_width, cend = cfg_name_len, hlname = "f_sr_opt_name" },
    }

    if flags ~= nil and #flags > 0 then
      for _, flag in ipairs(flags) do
        local extra = " " .. flag.icon .. " " ---@type string
        local next_value_start_pos = value_start_pos + #extra ---@type integer
        local hlflag = flag.enabled and "f_sr_flag_enabled" or "f_sr_flag"

        left = left .. extra
        table.insert(highlights, {
          cstart = value_start_pos,
          cend = next_value_start_pos,
          hlname = hlflag,
        })
        value_start_pos = next_value_start_pos
      end
      left = left .. " "
    end

    local val = state.get_value(key) ---@cast val string
    local value = string.gsub(val, "\n", "↲")
    table.insert(highlights, { cstart = value_start_pos, cend = -1, hlname = hlvalue })
    M.internal_print(left .. value, highlights, { key = key })
  end

  local mode_indicator = state.get_mode() == "search" and "[Search]" or "[Replace]"
  M.internal_print(mode_indicator .. " Press ? for mappings", { { cstart = 0, cend = -1, hlname = "f_sr_usage" } })
  print_cfg_field("cwd", "CWD", "f_sr_opt_value")
  print_cfg_field("search_paths", "Paths", "f_sr_opt_value")
  print_cfg_field("include_patterns", "Include", "f_sr_opt_value")
  print_cfg_field("exclude_patterns", "Exclude", "f_sr_opt_value")
  print_cfg_field("search_pattern", "Search", "f_sr_opt_search_pattern", {
    { icon = "󰑑", enabled = state.get_flag_regex() },
    { icon = "", enabled = state.get_flag_case_sensitive() },
  })
  if state.get_mode() == "replace" then
    print_cfg_field("replace_pattern", "Replace", "f_sr_opt_replace_pattern")
  end
end
