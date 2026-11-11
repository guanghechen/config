local harness = require("__test__.support.harness")
local support = require("__test__.support.theme")
local t = harness.new()

t:patch_global("yoz", require("yoz"))
t:patch_global("stl", require("stl"))
t:patch_global("dot", require("dot"))

t:test("common highlights use the selected mode palette and relink on mode changes", function()
  local common = require("dot.theme.hlgroup.common")
  local context = support.context_for("vsc-dark-modern")
  local modes_color_map = require("dot.theme.hlgroup.basic.vsc").gen_modes_color_map(context)
  local map = common.gen_hlgroup_map(context, modes_color_map)
  local applied = support.apply_integration(t, "common", context)
  t.assert_eq(tonumber(modes_color_map.insert:sub(2), 16), applied.ms_none_insert.fg)
  t.assert_eq(context.scheme.palette.vsc.accentPurple, map.ms_none_insert.fg)
  t.assert_eq(context.scheme.palette.vsc.accentAqua, map.mf_bg0_normal.bg)
  t.assert_eq("ms_none_normal", map.ms_none.link)

  local saved = {}
  t:defer(function()
    for name, hlgroup in pairs(saved) do
      vim.api.nvim_set_hl(0, name, hlgroup)
    end
  end)
  for name in pairs(map) do
    saved[name] = vim.api.nvim_get_hl(0, { name = name, link = true })
    vim.api.nvim_set_hl(0, name, map[name])
  end
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = "i", blocking = false }
  end)
  local mode, label = common.resolve_mode()
  t.assert_eq("insert", mode)
  t.assert_eq("INSERT", label)
  common.on_mode_changed()
  t.assert_eq("ms_none_insert", vim.api.nvim_get_hl(0, { name = "ms_none", link = true }).link)
  t.assert_eq("mf_b_bg0_insert", vim.api.nvim_get_hl(0, { name = "mf_b_bg0", link = true }).link)
end)

t:test("every mode that mode() documents resolves to its category", function()
  local common = require("dot.theme.hlgroup.common")
  local mode = "n" ---@type string
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = mode, blocking = false }
  end)

  -- From `:h mode()`, where "\22" is CTRL-V and "\19" is CTRL-S.
  -- stylua: ignore
  local categories = {
    n = "normal", no = "normal", nov = "normal", noV = "normal", ["no\22"] = "normal",
    niI = "normal", niR = "normal", niV = "normal", nt = "nterminal", ntT = "nterminal",
    v = "visual", vs = "visual", V = "visual", Vs = "visual", ["\22"] = "visual", ["\22s"] = "visual",
    s = "select", S = "select", ["\19"] = "select",
    i = "insert", ic = "insert", ix = "insert",
    R = "replace", Rc = "replace", Rx = "replace", Rv = "replace", Rvc = "replace", Rvx = "replace",
    c = "command", cr = "command", cv = "command", cvr = "command",
    r = "confirm", rm = "confirm", ["r?"] = "confirm", ["!"] = "terminal", t = "terminal",
  }
  local mismatches = {} ---@type string[]
  for value, category in pairs(categories) do
    mode = value
    local ok, resolved = pcall(common.resolve_mode)
    if not ok or resolved ~= category then
      mismatches[#mismatches + 1] = vim.fn.strtrans(value) .. ": " .. tostring(resolved)
    end
  end
  table.sort(mismatches)
  t.assert_same({}, mismatches, "modes resolved to another category or not at all")
end)

t:test("mode changes within a category leave highlights untouched and theme reloads keep the category", function()
  local common = require("dot.theme.hlgroup.common")
  local context = support.context_for("vsc-dark-modern")
  local modes_color_map = require("dot.theme.hlgroup.basic.vsc").gen_modes_color_map(context)
  local set_hl = vim.api.nvim_set_hl
  local saved = {}
  t:defer(function()
    for name, hlgroup in pairs(saved) do
      set_hl(0, name, hlgroup)
    end
  end)
  ---@return nil
  local function reload_theme()
    for name, hlgroup in pairs(common.gen_hlgroup_map(context, modes_color_map)) do
      saved[name] = saved[name] or vim.api.nvim_get_hl(0, { name = name, link = true })
      set_hl(0, name, hlgroup)
    end
  end

  local mode = "n" ---@type string
  t:patch_table(vim.api, "nvim_get_mode", function()
    return { mode = mode, blocking = false }
  end)
  -- Earlier cases may leave the module linked to another category.
  common.on_mode_changed()
  reload_theme()
  t.assert_eq("mf_b_bg0_normal", vim.api.nvim_get_hl(0, { name = "mf_b_bg0", link = true }).link)

  local calls = 0
  t:patch_table(vim.api, "nvim_set_hl", function(...)
    calls = calls + 1
    return set_hl(...)
  end)
  mode = "i"
  common.on_mode_changed()
  t.assert_true(calls > 0, "normal to insert relinks")

  calls = 0
  mode = "ic"
  common.on_mode_changed()
  mode = "i"
  common.on_mode_changed()
  t.assert_eq(0, calls, "insert completion keeps the insert links")

  reload_theme()
  t.assert_eq("mf_b_bg0_insert", vim.api.nvim_get_hl(0, { name = "mf_b_bg0", link = true }).link, "reload")
  common.on_mode_changed()
  t.assert_eq(0, calls, "no relink after a reload in the same category")

  mode = "n"
  common.on_mode_changed()
end)

t:run()
