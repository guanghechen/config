local fs = require("__test__.support.fs")
local harness = require("__test__.support.harness")
local support = require("__test__.support.theme")
local t = harness.new()

t:patch_global("yoz", require("yoz"))
t:patch_global("stl", require("stl"))
t:patch_global("dot", require("dot"))

t:test("symlink tints blend the active theme's link and Git colors with Git dominant", function()
  for _, name in ipairs(dot.var.themes) do
    local groups = support.apply_integration(t, "explorer", support.context_for(name))
    local link_color = groups.m_ex_symlink.fg
    for _, status in ipairs({
      "add",
      "change",
      "delete",
      "ignored",
      "other",
      "rename",
      "staged",
      "unmerged",
      "unstaged",
      "untracked",
    }) do
      local label = name .. "/" .. status
      local git_color = groups["m_ft_git_" .. status].fg
      local tint = assert(groups["m_ex_symlink_" .. status], label .. " missing link tint")
      t.assert_nil(tint.bg, label .. " preserves the row background")
      if link_color ~= git_color then
        t.assert_true(tint.fg ~= link_color and tint.fg ~= git_color, label .. " combines both colors")
      end
      for _, shift in ipairs({ 0, 8, 16 }) do
        local link_channel = bit.band(bit.rshift(link_color, shift), 255)
        local git_channel = bit.band(bit.rshift(git_color, shift), 255)
        local mixed_channel = bit.band(bit.rshift(tint.fg, shift), 255)
        t.assert_true(
          mixed_channel >= math.min(link_channel, git_channel) and mixed_channel <= math.max(link_channel, git_channel),
          label .. " channel remains between the source colors"
        )
        t.assert_true(
          math.abs(mixed_channel - git_channel) <= math.abs(mixed_channel - link_channel) + 1,
          label .. " favors the Git color"
        )
      end
    end
  end
end)

t:test("every category falls back to unified when its theme implementation is absent", function()
  local context = support.context_for("vsc-dark-modern")
  context.scheme = vim.deepcopy(context.scheme)
  context.scheme.theme = "missing-theme"
  for _, category in ipairs(support.CATEGORIES) do
    local module = "dot.theme.hlgroup." .. category
    local expected = require(module .. ".unified").gen_hlgroup_map(context)
    local actual = support.apply_integration(t, category, context)
    t.assert_same(support.render_hlgroup_map(expected), actual, category .. " fallback")
  end
  local modes_color_map = require("dot.theme.hlgroup.basic.unified").gen_modes_color_map(context)
  local expected = require("dot.theme.hlgroup.common").gen_hlgroup_map(context, modes_color_map)
  t.assert_same(
    support.render_hlgroup_map(expected),
    support.apply_integration(t, "common", context),
    "mode palette fallback"
  )
end)

t:test("all unified implementations depend only on the unified palette and transparency", function()
  for _, transparency in ipairs({ false, true }) do
    local context = support.context_for("vsc-dark-modern", transparency)
    local unified_context =
      { scheme = { palette = { unified = context.scheme.palette.unified } }, transparency = transparency }
    for _, category in ipairs(support.CATEGORIES) do
      local unified = require("dot.theme.hlgroup." .. category .. ".unified")
      t.assert_same(unified.gen_hlgroup_map(context), unified.gen_hlgroup_map(unified_context), category)
    end
  end
end)

t:test("theme implementations are selected from runtimepath without package.path entries", function()
  local context = support.context_for("vsc-dark-modern")
  t:patch_table(package.loaded, "dot.theme.hlgroup.lsp.vsc", nil)
  t:patch_table(package, "path", "")
  local map = support.apply_integration(t, "lsp", context)
  t.assert_eq(tonumber(context.scheme.palette.vsc.tokenInvalid:sub(2), 16), map["@lsp.mod.deprecated"].fg)
end)

t:test("a theme implementation replaces the entire map without implicit merging", function()
  local context = support.context_for("vsc-dark-modern")
  local expected = { ["@lsp.mod.deprecated"] = { link = "Comment" } }
  t:patch_table(package.loaded, "dot.theme.hlgroup.lsp.vsc", nil)
  t:patch_table(package.preload, "dot.theme.hlgroup.lsp.vsc", function()
    return {
      gen_hlgroup_map = function()
        return expected
      end,
    }
  end)
  t.assert_same(support.render_hlgroup_map(expected), support.apply_integration(t, "lsp", context))
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
    local dirpath = t:tempdir()
    fs.write(dirpath .. "/dot/theme/hlgroup/lsp/__test_failure__.lua", { scenario.source })
    t:patch_table(package, "path", dirpath .. "/?.lua")
    -- A synthetic family keeps runtimepath implementations from shadowing this package.path fixture.
    t:patch_table(package.loaded, "dot.theme.hlgroup.lsp.__test_failure__", nil)
    t:patch_table(package.loaded, "dot.theme.hlgroup.lsp.unified", {
      gen_hlgroup_map = function()
        error("unexpected unified fallback")
      end,
    })
    local context = support.context_for("vsc-dark-modern")
    context.scheme = vim.deepcopy(context.scheme)
    context.scheme.theme = "__test_failure__"
    t.assert_error(function()
      support.apply_integration(t, "lsp", context)
    end, scenario.message, scenario.name)
  end)
end

t:test("generator failures and incomplete implementations never use unified", function()
  local context = support.context_for("vsc-dark-modern")
  t:patch_table(package.loaded, "dot.theme.hlgroup.lsp.vsc", {
    gen_hlgroup_map = function()
      error("highlight generation failed")
    end,
  })
  t.assert_error(function()
    support.apply_integration(t, "lsp", context)
  end, "highlight generation failed")

  t:patch_table(package.loaded, "dot.theme.hlgroup.lsp.vsc", {})
  t.assert_false(
    pcall(function()
      return support.apply_integration(t, "lsp", context)
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
  local context = support.context_for("tokyonight-night")
  for _, category in ipairs({ "basic", "explorer", "module", "widget", "nvimbar" }) do
    local entry = require("dot.theme.hlgroup." .. category .. "." .. context.scheme.theme)
    local unified = require("dot.theme.hlgroup." .. category .. ".unified")
    local before = unified.gen_hlgroup_map(context)
    local first = entry.gen_hlgroup_map(context)
    local expected = vim.deepcopy(first)
    for _, hlgroup in pairs(first) do
      hlgroup.fg = "#abcdef"
    end
    t.assert_same(expected, entry.gen_hlgroup_map(context), category .. " fresh theme map")
    t.assert_same(before, unified.gen_hlgroup_map(context), category .. " pristine unified map")
  end
end)

t:run()
