---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.keystroke.pairs.rule" ---@type string

-- Ported from blink.pairs v0.5.0 (`lua/blink/pairs/rule.lua` and the default `mappings.pairs`; MIT License,
-- Copyright (c) 2025 Liam Dyer; see LICENSE.blink). Rules of equal priority keep their definition order.

---@alias era.keystroke.pairs.Predicate fun(ctx: era.keystroke.pairs.Context): boolean

---@class era.keystroke.pairs.IDefinition
---@field public [1]                    string Opening.
---@field public [2]                    string Closing.
---@field public key                    ?string The key that types it, when not the opening's first character.
---@field public languages              ?string[] Treesitter languages or filetypes at the cursor.
---@field public priority               ?integer
---@field public when                   ?era.keystroke.pairs.Predicate
---@field public enter                  ?boolean
---@field public space                  ?boolean|era.keystroke.pairs.Predicate

--- Languages a rule applies in, resolved on first use to the treesitter languages and filetypes they name.
---@class era.keystroke.pairs.ILanguages
---@field public languages              ?string[]
---@field public langs                  ?table<string, true>
---@field public filetypes              ?table<string, true>

---@class era.keystroke.pairs.Rule : era.keystroke.pairs.ILanguages
---@field public opening                string
---@field public closing                string
---@field public priority               integer
---@field public order                  integer Definition order among rules of equal priority.
---@field public when                   ?era.keystroke.pairs.Predicate
---@field public enter                  boolean
---@field public space                  boolean|era.keystroke.pairs.Predicate

---@class era.keystroke.pairs.rule
local M = {}

local MARKDOWN = { languages = { "markdown" } } ---@type era.keystroke.pairs.ILanguages

--- A string's text needs not balance: a bracket typed inside one stays single.
---@param ctx                           era.keystroke.pairs.Context
---@return boolean
local function outside_string(ctx)
  return not ctx.in_string
end

---@param ctx                           era.keystroke.pairs.Context
---@return boolean
local function markdown_task(ctx)
  local before = ctx:text_before_cursor() ---@type string
  return before:match("^%s*[%*%-+]%s+%[%s*$") ~= nil or before:match("^%s*%d+%.%s+%[%s*$") ~= nil
end

-- Rules in definition order, which breaks priority ties.
---@type era.keystroke.pairs.IDefinition[]
local DEFINITIONS = {
  { "<!--", "-->", key = "!", languages = { "html", "markdown", "markdown_inline" } },
  { "(", ")", when = outside_string },
  {
    "[",
    "]",
    when = outside_string,
    -- Markdown task items keep `[ ]` as typed.
    space = function(ctx)
      return not M.is_language(ctx, MARKDOWN) or not markdown_task(ctx)
    end,
  },
  { "{", "}", when = outside_string },
  {
    "'",
    "'''",
    when = function(ctx)
      return ctx:text_before_cursor(2) == "''"
    end,
    languages = { "python", "toml" },
  },
  {
    "'",
    "'",
    enter = false,
    space = false,
    -- Not after a word character, as in contractions, nor where a Rust lifetime or a math span starts.
    when = function(ctx)
      return ctx.filetype ~= "plaintext"
        and ctx.filetype ~= "scheme"
        and (not ctx:text_before_cursor(1):match("%w") or ctx:is_after_cursor("'"))
        and not ctx:captures("singlequote", "nopair")
    end,
  },
  { 'r#"', '"#', key = '"', languages = { "rust" }, priority = 100 },
  {
    '"',
    '"""',
    when = function(ctx)
      return ctx:text_before_cursor(2) == '""'
    end,
    languages = { "python", "elixir", "julia", "kotlin", "scala", "toml" },
  },
  { '"', '"', enter = false, space = false },
  {
    "`",
    "```",
    when = function(ctx)
      return ctx:text_before_cursor(2) == "``"
    end,
    languages = { "markdown", "markdown_inline", "typst", "vimwiki", "rmarkdown", "rmd", "quarto" },
  },
  { "`", "'", languages = { "bibtex", "latex", "plaintex" } },
  { "`", "`", enter = false, space = false },
  {
    "_",
    "_",
    when = function(ctx)
      return not ctx:text_before_cursor(1):match("%w") and not ctx:captures("underscore", "nopair")
    end,
    languages = { "typst" },
  },
  {
    "*",
    "*",
    when = function(ctx)
      return not ctx:captures("asterisk", "nopair")
    end,
    languages = { "typst" },
  },
  {
    "<",
    ">",
    when = function(ctx)
      return ctx:captures("angle", "pair")
    end,
    languages = { "rust" },
  },
  { "$", "$", languages = { "markdown", "markdown_inline", "typst", "latex", "plaintex" } },
}

-- Treesitter languages and the filetypes besides their own that use them, where Neovim registers none.
---@type table<string, string[]>
local LANG_FILETYPES = {
  bibtex = { "bib" },
  latex = { "tex" },
  markdown = { "pandoc" },
  markdown_inline = { "markdown" },
  python = { "gyp" },
  scala = { "sbt" },
}

--- Fills the treesitter languages and filetypes that `rule.languages` names, as blink.pairs' `get_langs` and
--- `get_filetypes` normalize each entry to both.
---@param rule                          era.keystroke.pairs.ILanguages
---@return nil
local function resolve_languages(rule)
  local langs, filetypes = {}, {} ---@type table<string, true>, table<string, true>
  local languages = rule.languages or {} ---@type string[]
  for _, name in ipairs(languages) do
    langs[name], filetypes[name] = true, true
    local lang = vim.treesitter.language.get_lang(name) ---@type string|nil
    if lang then
      langs[lang] = true
    end
    for _, filetype in ipairs(LANG_FILETYPES[name] or {}) do
      filetypes[filetype] = true
    end
    for _, filetype in ipairs(vim.treesitter.language.get_filetypes(name)) do
      filetypes[filetype] = true
    end
  end
  for lang, names in pairs(LANG_FILETYPES) do
    for _, filetype in ipairs(names) do
      if vim.tbl_contains(languages, filetype) then
        langs[lang] = true
      end
    end
  end
  rule.langs, rule.filetypes = langs, filetypes
end

--- Whether the treesitter language at the cursor, or without a parser the filetype, is one `rule.languages` names.
---@param ctx                           era.keystroke.pairs.Context
---@param rule                          era.keystroke.pairs.ILanguages
---@return boolean
function M.is_language(ctx, rule)
  if rule.langs == nil then
    resolve_languages(rule)
  end
  local lang = ctx.lang
  if lang then
    return rule.langs[lang] == true
  end
  return rule.filetypes[ctx.filetype] == true
end

--- Whether `rule` applies here, and for `mode` also allows that action.
---@param ctx                           era.keystroke.pairs.Context
---@param rule                          era.keystroke.pairs.Rule
---@param mode                          ?"enter"|"space"
---@return boolean
function M.is_active(ctx, rule, mode)
  if rule.languages and not M.is_language(ctx, rule) then
    return false
  end
  if rule.when and not rule.when(ctx) then
    return false
  end
  if mode == "enter" then
    return rule.enter
  elseif mode == "space" then
    local space = rule.space
    if type(space) == "function" then
      return space(ctx)
    end
    return space
  end
  return true
end

---@param definition                    era.keystroke.pairs.IDefinition
---@param order                         integer
---@return era.keystroke.pairs.Rule
local function rule_of(definition, order)
  local opening, closing = definition[1], definition[2] ---@type string, string
  local space = definition.space ---@type boolean|era.keystroke.pairs.Predicate|nil
  return {
    opening = opening,
    closing = closing,
    priority = definition.priority or (#closing + #opening + (definition.when and 4 or 0)),
    order = order,
    languages = definition.languages,
    when = definition.when,
    enter = definition.enter ~= false,
    space = space == nil and true or space,
  }
end

---@param a                             era.keystroke.pairs.Rule
---@param b                             era.keystroke.pairs.Rule
---@return boolean
local function by_priority(a, b)
  if a.priority ~= b.priority then
    return a.priority > b.priority
  end
  return a.order < b.order
end

--- Rules by the key that types them: a rule's opening key, and the first character of its closing when another key.
--- Also returns every rule, for the keys that look on both sides of the cursor.
---@return table<string, era.keystroke.pairs.Rule[]>
---@return era.keystroke.pairs.Rule[]
function M.build()
  local by_key = {} ---@type table<string, era.keystroke.pairs.Rule[]>
  local all = {} ---@type era.keystroke.pairs.Rule[]
  for order, definition in ipairs(DEFINITIONS) do
    local rule = rule_of(definition, order)
    all[order] = rule
    local key = definition.key or rule.opening:sub(1, 1) ---@type string
    by_key[key] = by_key[key] or {}
    table.insert(by_key[key], rule)
    local closing_key = rule.closing:sub(1, 1) ---@type string
    if closing_key ~= key then
      by_key[closing_key] = by_key[closing_key] or {}
      table.insert(by_key[closing_key], rule)
    end
  end
  for _, rules in pairs(by_key) do
    table.sort(rules, by_priority)
  end
  table.sort(all, by_priority)
  return by_key, all
end

return M
