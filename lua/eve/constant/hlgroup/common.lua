---@class eve.constant.hlgroup.common.modes_color_map
---@field public command                std.t.theme.IHlgroup
---@field public confirm                std.t.theme.IHlgroup
---@field public insert                 std.t.theme.IHlgroup
---@field public normal                 std.t.theme.IHlgroup
---@field public select                 std.t.theme.IHlgroup
---@field public terminal               std.t.theme.IHlgroup
---@field public visual                 std.t.theme.IHlgroup

---@class eve.constant.hlgroup.common.modes_map
local modes_map = {
  ["n"] = { "normal", "NORMAL" },
  ["no"] = { "normal", "NORMAL (no)" },
  ["nov"] = { "normal", "NORMAL (nov)" },
  ["noV"] = { "normal", "NORMAL (noV)" },
  ["noCTRL-V"] = { "normal", "NORMAL" },
  ["niI"] = { "normal", "NORMAL i" },
  ["niR"] = { "normal", "NORMAL r" },
  ["niV"] = { "normal", "NORMAL v" },
  ["nt"] = { "nterminal", "NTERMINAL" },
  ["ntT"] = { "nterminal", "NTERMINAL (ntT)" },
  ["v"] = { "visual", "VISUAL" },
  ["vs"] = { "visual", "V-CHAR (Ctrl O)" },
  ["V"] = { "visual", "V-LINE" },
  ["Vs"] = { "visual", "V-LINE" },
  [""] = { "visual", "V-BLOCK" },
  ["i"] = { "insert", "INSERT" },
  ["ic"] = { "insert", "INSERT (completion)" },
  ["ix"] = { "insert", "INSERT completion" },
  ["t"] = { "terminal", "TERMINAL" },
  ["R"] = { "replace", "REPLACE" },
  ["Rc"] = { "replace", "REPLACE (Rc)" },
  ["Rx"] = { "replace", "REPLACEa (Rx)" },
  ["Rv"] = { "replace", "V-REPLACE" },
  ["Rvc"] = { "replace", "V-REPLACE (Rvc)" },
  ["Rvx"] = { "replace", "V-REPLACE (Rvx)" },
  ["s"] = { "select", "SELECT" },
  ["S"] = { "select", "S-LINE" },
  [""] = { "select", "S-BLOCK" },
  ["c"] = { "command", "COMMAND" },
  ["cv"] = { "command", "COMMAND" },
  ["ce"] = { "command", "COMMAND" },
  ["r"] = { "confirm", "PROMPT" },
  ["rm"] = { "confirm", "MORE" },
  ["r?"] = { "confirm", "CONFIRM" },
  ["x"] = { "confirm", "CONFIRM" },
  ["!"] = { "terminal", "SHELL" },
}

---@class eve.constant.hlgroup.common
local M = {}

---@type string[]
local colors = {
  "none",
  "bg0",
  "bg1",
  "bg2",
  "bg3",
  "bg4",
  -- "fg0",
  -- "fg1",
  -- "fg2",
  -- "fg3",
  -- "fg4",
  -- "red",
  -- "green",
  -- "yellow",
  -- "blue",
  -- "purple",
  -- "aqua",
  -- "orange",
  -- "grey",
  -- "pink",
}

---@return string
---@return string
function M.resolve_mode()
  local mode = vim.api.nvim_get_mode().mode ---@type string
  local m = modes_map[mode]
  return m[1], m[2]
end

---@param context                       std.t.theme.IContext
---@return table<string, std.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local c = context.scheme.palette.unified ---@type std.t.theme.UnifiedPalette
  local basic = require("eve.constant.hlgroup.basic") ---@type eve.constant.hlgroup.basic
  local mc = basic.gen_modes_color_map(context) ---@type eve.constant.hlgroup.common.modes_color_map

  local hlgroup_map = {} ---@type table<string, std.t.theme.IHlgroup>
  for _, color in ipairs(colors) do
    for mode, mode_color in pairs(mc) do
      local suffix = string.format("_%s_%s", color, mode) ---@type string

      -- stylua: ignore start
      hlgroup_map["mf" .. suffix]     = { fg = c[color], bg = mode_color }
      hlgroup_map["mf_b" .. suffix]   = { fg = c[color], bg = mode_color, bold = true }
      hlgroup_map["mf_bi" .. suffix]  = { fg = c[color], bg = mode_color, bold = true, italic = true }
      hlgroup_map["mf_i" .. suffix]   = { fg = c[color], bg = mode_color, italic = true }

      hlgroup_map["ms" .. suffix]     = { fg = mode_color, bg = c[color] }
      hlgroup_map["ms_b" .. suffix]   = { fg = mode_color, bg = c[color], bold = true }
      hlgroup_map["ms_bi" .. suffix]  = { fg = mode_color, bg = c[color], bold = true, italic = true }
      hlgroup_map["ms_i" .. suffix]   = { fg = mode_color, bg = c[color], italic = true }
      -- stylua: ignore end
    end

    -- stylua: ignore start
    hlgroup_map["mf_"     .. color] = { link = "mf_"    .. color .. "_normal" }
    hlgroup_map["mf_b_"   .. color] = { link = "mf_b_"  .. color .. "_normal" }
    hlgroup_map["mf_bi_"  .. color] = { link = "mf_bi_" .. color .. "_normal" }
    hlgroup_map["mf_i_"   .. color] = { link = "mf_i_"  .. color .. "_normal" }
    hlgroup_map["ms_"     .. color] = { link = "ms_"    .. color .. "_normal" }
    hlgroup_map["ms_b_"   .. color] = { link = "ms_b_"  .. color .. "_normal" }
    hlgroup_map["ms_bi_"  .. color] = { link = "ms_bi_" .. color .. "_normal" }
    hlgroup_map["ms_i_"   .. color] = { link = "ms_i_"  .. color .. "_normal" }
    -- stylua: ignore end
  end

  return hlgroup_map
end

---@return nil
function M.on_mode_changed()
  local mode = M.resolve_mode() ---@type string

  for _, color in ipairs(colors) do
    -- stylua: ignore start
    vim.api.nvim_set_hl(0, "mf_"    .. color, { link = "mf_"    .. color .. "_" .. mode })
    vim.api.nvim_set_hl(0, "mf_b_"  .. color, { link = "mf_b_"  .. color .. "_" .. mode })
    vim.api.nvim_set_hl(0, "mf_bi_" .. color, { link = "mf_bi_" .. color .. "_" .. mode })
    vim.api.nvim_set_hl(0, "mf_i_"  .. color, { link = "mf_i_"  .. color .. "_" .. mode })
    vim.api.nvim_set_hl(0, "ms_"    .. color, { link = "ms_"    .. color .. "_" .. mode })
    vim.api.nvim_set_hl(0, "ms_b_"  .. color, { link = "ms_b_"  .. color .. "_" .. mode })
    vim.api.nvim_set_hl(0, "ms_bi_" .. color, { link = "ms_bi_" .. color .. "_" .. mode })
    vim.api.nvim_set_hl(0, "ms_i_"  .. color, { link = "ms_i_"  .. color .. "_" .. mode })
    -- stylua: ignore end
  end
end

return M
