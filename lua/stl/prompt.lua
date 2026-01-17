-- Pattern: __[A-Z_]+__
local VAR_NAME_PATTERN = "^(__[A-Z_]+__)$"
-- Assignment pattern: __VAR__=value or __VAR__="quoted value"
local VAR_ASSIGN_PATTERN = "^(__[A-Z_]+__)=(.*)$"
-- Reference pattern: ${__VAR__}
local VAR_REF_PATTERN = "%${(__[A-Z_]+__)}"

---@alias stl.prompt.AgentEnum "claude"|"codex"|"copilot"|"gemini"|"opencode"

---Builtin slash commands per agent (these are NOT transformed).
---@type table<stl.prompt.AgentEnum, table<string, boolean>>
local BUILTIN_COMMANDS = {
  claude = {
    ["/add-dir"] = true,
    ["/clear"] = true,
    ["/compact"] = true,
    ["/config"] = true,
    ["/cost"] = true,
    ["/doctor"] = true,
    ["/help"] = true,
    ["/init"] = true,
    ["/install-github-app"] = true,
    ["/login"] = true,
    ["/logout"] = true,
    ["/mcp"] = true,
    ["/memory"] = true,
    ["/model"] = true,
    ["/permissions"] = true,
    ["/pr-comments"] = true,
    ["/review"] = true,
    ["/status"] = true,
    ["/terminal-setup"] = true,
    ["/vim"] = true,
  },
  codex = {
    ["/help"] = true,
    ["/model"] = true,
    ["/approval"] = true,
    ["/providers"] = true,
    ["/history"] = true,
    ["/clear"] = true,
    ["/compact"] = true,
  },
  copilot = {
    ["/clear"] = true,
    ["/clearHistory"] = true,
    ["/explain"] = true,
    ["/fix"] = true,
    ["/generate"] = true,
    ["/help"] = true,
    ["/new"] = true,
    ["/newNotebook"] = true,
    ["/search"] = true,
    ["/tests"] = true,
  },
  gemini = {
    ["/about"] = true,
    ["/auth"] = true,
    ["/bug"] = true,
    ["/chat"] = true,
    ["/clear"] = true,
    ["/compress"] = true,
    ["/copy"] = true,
    ["/dir"] = true,
    ["/directory"] = true,
    ["/editor"] = true,
    ["/exit"] = true,
    ["/extensions"] = true,
    ["/help"] = true,
    ["/init"] = true,
    ["/mcp"] = true,
    ["/memory"] = true,
    ["/model"] = true,
    ["/privacy"] = true,
    ["/quit"] = true,
    ["/restore"] = true,
    ["/resume"] = true,
    ["/rewind"] = true,
    ["/settings"] = true,
    ["/skills"] = true,
    ["/stats"] = true,
    ["/theme"] = true,
    ["/tools"] = true,
    ["/vim"] = true,
  },
  opencode = {
    ["/connect"] = true,
    ["/help"] = true,
    ["/init"] = true,
    ["/redo"] = true,
    ["/share"] = true,
    ["/undo"] = true,
  },
}

---@param text                          string
---@param i                             integer
---@return string|nil
---@return integer|nil
local function match_slash_command(text, i)
  local is_valid_start = (i == 1) or text:sub(i - 1, i - 1):match("[%s]")
  if not is_valid_start or text:sub(i, i) ~= "/" then
    return nil, nil
  end

  local cmd = text:match("^(/[%w%-]+)", i)
  if not cmd then
    return nil, nil
  end

  local after_pos = i + #cmd
  if text:sub(after_pos, after_pos) == "/" then
    return nil, nil
  end

  return cmd, after_pos
end

---Transform slash commands for a specific agent.
---Only matches `/command` preceded by whitespace, newline, or at start of string.
---Slash commands must NOT be followed by `/` (to avoid matching paths like /usr/local).
---Builtin commands (in the builtins table) are NOT transformed.
---@param text                          string
---@param transformer                   fun(cmd: string): string
---@param builtins                      ?table<string, boolean>
---@return string
local function transform_slash_commands(text, transformer, builtins)
  local result = {} ---@type string[]
  local i = 1
  local len = #text

  while i <= len do
    local cmd, after_pos = match_slash_command(text, i)
    if cmd and after_pos then
      local transformed = (builtins and builtins[cmd]) and cmd or transformer(cmd)
      result[#result + 1] = transformed
      i = after_pos
    else
      result[#result + 1] = text:sub(i, i)
      i = i + 1
    end
  end

  return table.concat(result)
end

---@type table<stl.prompt.AgentEnum, fun(cmd: string): string>
local SLASH_TRANSFORMERS = {
  claude = function(cmd)
    return cmd
  end,
  codex = function(cmd)
    -- /command -> /prompts:command
    return "/prompts:" .. cmd:sub(2)
  end,
  copilot = function(cmd)
    return cmd
  end,
  gemini = function(cmd)
    return cmd
  end,
  opencode = function(cmd)
    return cmd
  end,
}

---@class stl.prompt
local M = {}

----------------------------------------------------------------------------------------------------
-- Prompt Templates
----------------------------------------------------------------------------------------------------

---@class stl.prompt.ITemplate
---@field public name                   string
---@field public template               string
---@field public submit                 boolean
---@field public conditional            ?fun(ctx: stl.prompt.ITemplateCtx): boolean

---@class stl.prompt.ITemplateCtx
---@field public has_selection          boolean
---@field public has_file               boolean
---@field public has_diagnostics        boolean
---@field public has_diagnostics_all    boolean

---@type stl.prompt.ITemplate[]
M.templates = {
  {
    name = "diagnostics",
    submit = true,
    template = "Fix the diagnostics in ${__FILE__}:\n${__DIAGNOSTICS__}",
    conditional = function(ctx)
      return ctx.has_file and ctx.has_diagnostics
    end,
  },
  {
    name = "diagnostics_all",
    submit = true,
    template = "Fix these diagnostics:\n${__DIAGNOSTICS_ALL__}",
    conditional = function(ctx)
      return ctx.has_diagnostics_all
    end,
  },
  {
    name = "fix",
    submit = true,
    template = "Fix this code: ${__TARGET__}",
    conditional = function(ctx)
      return ctx.has_file
    end,
  },
  {
    name = "optimize",
    submit = true,
    template = "Optimize this code: ${__TARGET__}",
    conditional = function(ctx)
      return ctx.has_file
    end,
  },
  {
    name = "refactor",
    submit = true,
    template = "Refactor this code: ${__TARGET__}",
    conditional = function(ctx)
      return ctx.has_file
    end,
  },
  {
    name = "review",
    submit = true,
    template = "Review this code: ${__TARGET__}",
    conditional = function(ctx)
      return ctx.has_file
    end,
  },
}

---Get a prompt template by name.
---@param name                          string
---@return stl.prompt.ITemplate|nil
function M.get_template(name)
  for _, t in ipairs(M.templates) do
    if t.name == name then
      return t
    end
  end
  return nil
end

----------------------------------------------------------------------------------------------------
-- Variable Substitution
----------------------------------------------------------------------------------------------------

---Parse and substitute variables in text.
---
---**Variable Naming:** `__[A-Z_]+__` (e.g., `__FILE_PATH__`, `__SELECTION_TEXT__`)
---
---**Variable Assignment:** Must be on its own line.
---- `__VAR__=value`
---- `__VAR__="value with spaces"`
---
---**Variable Reference:** `${__VAR__}` (inline). If not defined, kept as-is.
---
---**Rendering:**
---1. Parse and collect all variable assignments
---2. Remove assignment lines from output
---3. Replace `${__VAR__}` references (only if variable exists)
---4. Trim leading/trailing whitespace
---
---@param text                          string
---@return string
function M.substitute(text)
  local vars = {} ---@type table<string, string>
  local output_lines = {} ---@type string[]

  for line in vim.gsplit(text, "\n", { plain = true }) do
    local var_name, var_value = line:match(VAR_ASSIGN_PATTERN)
    if var_name and var_name:match(VAR_NAME_PATTERN) then
      -- Handle quoted values
      if var_value:match('^"(.*)"$') then
        var_value = var_value:match('^"(.*)"$')
      end
      vars[var_name] = var_value
    else
      output_lines[#output_lines + 1] = line
    end
  end

  local result = table.concat(output_lines, "\n")

  -- Replace references (only if variable exists)
  result = result:gsub(VAR_REF_PATTERN, function(var_name)
    local value = vars[var_name]
    if value then
      return value
    end
    return "${" .. var_name .. "}"
  end)

  return vim.trim(result)
end

---Render text for a specific agent.
---
---Performs variable substitution and transforms slash commands based on agent.
---- claude/copilot/gemini/opencode: `/command` (unchanged)
---- codex: `/command` -> `/prompts:command`
---
---Builtin commands for each agent are preserved (not transformed).
---
---@param text                          string
---@param agent                         stl.prompt.AgentEnum
---@return string
function M.render(text, agent)
  local result = M.substitute(text)

  local transformer = SLASH_TRANSFORMERS[agent]
  if transformer then
    local builtins = BUILTIN_COMMANDS[agent]
    result = transform_slash_commands(result, transformer, builtins)
  end

  return result
end

return M
