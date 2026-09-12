---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.dot.theme.hlgroup_spec" ---@type string

local harness = require("__test__.support.harness")
local t = harness.new("dot.theme.hlgroup")

t:patch_global("yoz", require("yoz"))
t:patch_global("stl", require("stl"))
t:patch_global("dot", require("dot"))
local theme = dot.context.theme

local categories = { "basic", "lsp", "module", "nvimbar", "plugin", "treesitter", "widget" }

---@param name                          string
---@param transparency                  ?boolean
---@return stl.t.theme.IContext
local function context_for(name, transparency)
  local scheme = require("dot.theme.scheme." .. name)
  return { scheme = scheme, theme = scheme.theme, variant = scheme.variant, transparency = transparency == true }
end

---@param map                           table<string, stl.t.theme.IHlgroup>
---@return table<string, vim.api.keyset.get_hl_info>
local function render_hlgroup_map(map)
  local nsnr = vim.api.nvim_create_namespace("")
  for name, hlgroup in pairs(map) do
    vim.api.nvim_set_hl(nsnr, name, hlgroup)
  end
  return vim.api.nvim_get_hl(nsnr, { link = true })
end

---@param integration                   dot.e.ThemeIntegration
---@param context                       stl.t.theme.IContext
---@return table<string, vim.api.keyset.get_hl_info>
local function apply_integration(integration, context)
  local restore = t:patch_table(theme, "get_scheme", function()
    return context.scheme
  end)
  local nsnr = vim.api.nvim_create_namespace("")
  theme.apply_integration({
    theme = "vsc-dark-modern",
    transparency = context.transparency,
    integration = integration,
    nsnr = nsnr,
  })
  restore()
  return vim.api.nvim_get_hl(nsnr, { link = true })
end

t:test("every category falls back to unified when its theme implementation is absent", function()
  local context = context_for("vsc-dark-modern")
  context.scheme = vim.deepcopy(context.scheme)
  context.scheme.theme = "missing-theme"
  for _, category in ipairs(categories) do
    local module = "dot.theme.hlgroup." .. category
    local expected = require(module .. ".unified").gen_hlgroup_map(context)
    local actual = apply_integration(category, context)
    t.assert_true(vim.deep_equal(render_hlgroup_map(expected), actual), category .. " fallback")
  end
  local modes_color_map = require("dot.theme.hlgroup.basic.unified").gen_modes_color_map(context)
  local expected = require("dot.theme.hlgroup.common").gen_hlgroup_map(context, modes_color_map)
  t.assert_true(
    vim.deep_equal(render_hlgroup_map(expected), apply_integration("common", context)),
    "mode palette fallback"
  )
end)

t:test("all unified implementations depend only on the unified palette and transparency", function()
  for _, transparency in ipairs({ false, true }) do
    local context = context_for("vsc-dark-modern", transparency)
    local unified_context =
      { scheme = { palette = { unified = context.scheme.palette.unified } }, transparency = transparency }
    for _, category in ipairs(categories) do
      local unified = require("dot.theme.hlgroup." .. category .. ".unified")
      t.assert_true(
        vim.deep_equal(unified.gen_hlgroup_map(context), unified.gen_hlgroup_map(unified_context)),
        category
      )
    end
  end
end)

t:test("theme implementations are selected from runtimepath without package.path entries", function()
  local context = context_for("vsc-dark-modern")
  t:patch_table(package.loaded, "dot.theme.hlgroup.lsp.vsc", nil)
  t:patch_table(package, "path", "")
  local map = apply_integration("lsp", context)
  t.assert_eq(tonumber(context.scheme.palette.vsc.tokenInvalid:sub(2), 16), map["@lsp.mod.deprecated"].fg)
end)

t:test("a theme implementation replaces the entire map without implicit merging", function()
  local context = context_for("vsc-dark-modern")
  local expected = { ["@lsp.mod.deprecated"] = { link = "Comment" } }
  t:patch_table(package.loaded, "dot.theme.hlgroup.lsp.vsc", nil)
  t:patch_table(package.preload, "dot.theme.hlgroup.lsp.vsc", function()
    return {
      gen_hlgroup_map = function()
        return expected
      end,
    }
  end)
  t.assert_true(vim.deep_equal(render_hlgroup_map(expected), apply_integration("lsp", context)))
end)

for _, scenario in ipairs({
  { name = "syntax error", source = "return {", message = "error loading module" },
  { name = "runtime error", source = 'error("theme implementation failed")', message = "theme implementation failed" },
  {
    name = "missing dependency",
    source = 'require("__missing_theme_dependency__")',
    message = "__missing_theme_dependency__",
  },
}) do
  t:test("an implementation " .. scenario.name .. " propagates instead of falling back", function()
    local dirpath = vim.fn.tempname()
    vim.fn.mkdir(dirpath .. "/dot/theme/hlgroup/lsp", "p")
    t:defer(function()
      vim.fn.delete(dirpath, "rf")
    end)
    local filepath = dirpath .. "/dot/theme/hlgroup/lsp/__test_failure__.lua"
    vim.fn.writefile({ scenario.source }, filepath)
    t:patch_table(package, "path", dirpath .. "/?.lua")
    -- A synthetic family keeps runtimepath implementations from shadowing this package.path fixture.
    t:patch_table(package.loaded, "dot.theme.hlgroup.lsp.__test_failure__", nil)
    t:patch_table(package.loaded, "dot.theme.hlgroup.lsp.unified", {
      gen_hlgroup_map = function()
        error("unexpected unified fallback")
      end,
    })
    local context = context_for("vsc-dark-modern")
    context.scheme = vim.deepcopy(context.scheme)
    context.scheme.theme = "__test_failure__"
    local ok, err = pcall(apply_integration, "lsp", context)
    t.assert_false(ok, scenario.name)
    t.assert_true(tostring(err):find(scenario.message, 1, true) ~= nil, tostring(err))
  end)
end

t:test("generator failures and incomplete implementations never use unified", function()
  local context = context_for("vsc-dark-modern")
  t:patch_table(package.loaded, "dot.theme.hlgroup.lsp.vsc", {
    gen_hlgroup_map = function()
      error("highlight generation failed")
    end,
  })
  local ok, err = pcall(function()
    return apply_integration("lsp", context)
  end)
  t.assert_false(ok)
  t.assert_true(tostring(err):find("highlight generation failed", 1, true) ~= nil, tostring(err))

  t:patch_table(package.loaded, "dot.theme.hlgroup.lsp.vsc", {})
  t.assert_false(
    pcall(function()
      return apply_integration("lsp", context)
    end),
    "missing generator"
  )
end)

t:test("theme surface overrides preserve their colors across variants and transparency", function()
  for _, family in ipairs({ "kanagawa", "tokyonight", "catppuccin" }) do
    local filepaths = vim.api.nvim_get_runtime_file("lua/dot/theme/scheme/" .. family .. "-*.lua", true)
    t.assert_true(#filepaths > 0, "missing schemes for " .. family)
    for _, filepath in ipairs(filepaths) do
      local scheme = assert(loadfile(filepath))()
      local u = scheme.palette.unified
      for _, transparency in ipairs({ false, true }) do
        local context = { scheme = scheme, transparency = transparency }
        local module = require("dot.theme.hlgroup.module." .. context.scheme.theme).gen_hlgroup_map(context)
        local widget = require("dot.theme.hlgroup.widget." .. context.scheme.theme).gen_hlgroup_map(context)
        t.assert_eq(u.fg1, module.m_dv_add_inline.fg, filepath)
        t.assert_eq(u.diffDelInline, module.m_dv_del_inline.bg, filepath)
        t.assert_eq(u.fg1, widget.f_diff_word_left.fg, filepath)
        t.assert_eq(u.diffAddInline, widget.f_diff_word_right.bg, filepath)
        if family ~= "catppuccin" then
          t.assert_eq(u.fg1, module.m_ft_git_ignored_cl.fg, filepath)
          t.assert_eq(u.fg2, module.m_dv_winbar_dim.fg, filepath)
          t.assert_eq(u.bg3, widget.f_matched_pairs_0.bg, filepath)
          t.assert_eq(u.fg1, widget.f_md_code_fallback.fg, filepath)
          t.assert_eq(u.bg2, widget.f_md_code_inline.bg, filepath)
          t.assert_eq(u.yellow, widget.f_md_text_inline_highlight.bg, filepath)
        end
        if family == "kanagawa" then
          local basic = require("dot.theme.hlgroup.basic." .. context.scheme.theme).gen_hlgroup_map(context)
          t.assert_eq(u.bg3, basic.Visual.bg, filepath)
          t.assert_eq(u.fg1, basic.Visual.fg, filepath)
          t.assert_eq(u.fg3, basic.ComplHint.fg, filepath)
        elseif family == "tokyonight" then
          t.assert_eq(u.fg3, module.m_git_buffer_blame.fg, filepath)
          t.assert_eq(stl.color.mix(u.bg0, u.green, 80), module.m_git_sign_add_staged.fg, filepath)
          local nvimbar = require("dot.theme.hlgroup.nvimbar." .. context.scheme.theme).gen_hlgroup_map(context)
          for _, position in ipairs({ "f_sl", "f_tl", "f_wl" }) do
            t.assert_eq(u.fg1, nvimbar[position .. "_term_button"].fg, filepath)
            t.assert_eq(u.bg4, nvimbar[position .. "_term_index"].bg, filepath)
          end
        end
      end
    end
  end
end)

t:test("theme overrides do not mutate later unified or theme results", function()
  local context = context_for("tokyonight-night")
  for _, category in ipairs({ "basic", "module", "widget", "nvimbar" }) do
    local entry = require("dot.theme.hlgroup." .. category .. "." .. context.scheme.theme)
    local unified = require("dot.theme.hlgroup." .. category .. ".unified")
    local before = unified.gen_hlgroup_map(context)
    local first = entry.gen_hlgroup_map(context)
    local expected = vim.deepcopy(first)
    for _, hlgroup in pairs(first) do
      hlgroup.fg = "#abcdef"
    end
    t.assert_true(vim.deep_equal(expected, entry.gen_hlgroup_map(context)), category .. " fresh theme map")
    t.assert_true(vim.deep_equal(before, unified.gen_hlgroup_map(context)), category .. " pristine unified map")
  end
end)

t:test("common highlights use the selected mode palette and relink on mode changes", function()
  local common = require("dot.theme.hlgroup.common")
  local context = context_for("vsc-dark-modern")
  local modes_color_map = require("dot.theme.hlgroup.basic.vsc").gen_modes_color_map(context)
  local map = common.gen_hlgroup_map(context, modes_color_map)
  local applied = apply_integration("common", context)
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

t:run()
