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
---@field public args                   ?table<string, string> Variable name to default value mapping, prompts user at runtime

---@class stl.prompt.ITemplateCtx
---@field public has_selection          boolean
---@field public has_file               boolean
---@field public has_diagnostics        boolean
---@field public has_diagnostics_all    boolean

---@type stl.prompt.ITemplate[]
M.templates = {
  {
    name = "review-design",
    submit = true,
    args = { __TMUX_PANE__ = "#3" },
    template = [[若你对当前设计仍有困惑或担忧，请与 tmux pane ${__TMUX_PANE__} 中运行的 agent 进行讨论。

为便于沟通，我们定义**"处境"**一词，表示以下要素的集合：背景故事、核心目标、关注指标、已确认的设计、待讨论的设计、潜在风险与困境、当前思路。

## 执行步骤

1. **整理处境**：梳理当前"处境"，以清晰友好的表述发送给 pane ${__TMUX_PANE__} 的 agent，请求其：
   - 提供建议与反馈
   - 查漏补缺：检查是否有考虑欠缺的地方
   - 审视现有设计是否存在缺陷或隐患
2. **分析回复**：收到对方回复后，综合分析并更新"处境"与计划
3. **迭代协商**：重复上述步骤，直至满足以下任一条件：
   - 双方达成共识，整理出明确的计划与待关注事项
   - 遇到无法确定的问题，需要我介入解答
   - 对方持续重复或未能提供有价值的内容（可提前退出）
4. **输出总结**：达成共识后，整理讨论结果并向我汇报，标注需要我关注的要点

## 注意事项

1. **输入延迟**：agent TUI 存在 debounce，发送内容后等待约 1 秒发送一次 `C-m`，再等待约 3 秒发送第二次 `C-m` 以确保触发
2. **保持耐心**：此过程耗时较长，这是预期内的，请从容应对
3. **批判性倾听**：对方的建议仅代表一种观点，不必全盘接受，但也应审慎考量——既不盲从，也不轻视
4. **精准提问**：这是双向对话，每次提问应有针对性，避免重复冗余]],
  },
  {
    name = "review-changes",
    submit = true,
    args = { __TMUX_PANE__ = "#3" },
    template = [[请与 tmux pane ${__TMUX_PANE__} 中运行的 agent 协作，对当前改动进行 code review。

为便于沟通，我们定义**"处境"**一词，表示以下要素的集合：背景故事、核心目标、关注指标、已确认的设计、待讨论的设计、潜在风险与困境、当前思路。

## 执行步骤

1. **发起 Review**：梳理当前"处境"与改动内容，以清晰友好的表述发送给 pane ${__TMUX_PANE__} 的 agent，请求其：
   - 审查代码改动，提出有价值的 review comments
   - 查漏补缺：检查是否有考虑欠缺的地方
   - 指出潜在问题、设计缺陷或隐患
2. **处理反馈**：收到 review comments 后：
   - 对于合理的问题：立即修复
   - 对于存疑的建议：与对方讨论，明确是否需要处理
3. **迭代审查**：修复完成后，再次请求 review，重复上述步骤，直至满足以下任一条件：
   - 对方无更多意见，review 通过
   - 双方达成共识，将剩余问题记录为 plan/todo 后续处理
   - 遇到无法确定的问题，需要我介入决策
   - 对方持续重复或未能提供有价值的内容（可提前退出）
4. **输出总结**：向我汇报最终结论，必须包含：
   - Review 结果概述
   - 已修复的问题清单
   - Plan/Todo 清单（如有后续待办事项）
   - Workaround 说明（如有临时方案或权宜之计）

## 注意事项

1. **输入延迟**：agent TUI 存在 debounce，发送内容后等待约 1 秒发送一次 `C-m`，再等待约 3 秒发送第二次 `C-m` 以确保触发
2. **保持耐心**：此过程耗时较长，这是预期内的，请从容应对
3. **批判性倾听**：对方的建议仅代表一种观点，不必全盘接受，但也应审慎考量——既不盲从，也不轻视
4. **精准沟通**：这是双向对话，每次交流应有针对性，避免重复冗余]],
  },
  {
    name = "review-diagnostics-neovim",
    submit = true,
    args = { __TMUX_PANE__ = "#3" },
    template = [[请修复所有 LSP diagnostic issues，直到没有任何需要修复的诊断信息。

## 前置准备

仔细阅读 `@spec/debug/lsp.md` 中的引导，理解如何获取 LSP 诊断信息。你可以使用 tmux pane ${__TMUX_PANE__} 来执行相关操作。

## 执行步骤

1. **获取诊断**：通过 pane ${__TMUX_PANE__} 获取当前所有 LSP diagnostics
2. **分析问题**：逐一分析每条诊断信息，理解其含义与修复方式
3. **修复问题**：
   - 对于明确的问题：立即修复
   - 对于不确定的问题：记录下来，稍后讨论
4. **迭代检查**：修复完成后，重新获取诊断，重复上述步骤，直至满足以下任一条件：
   - 无任何 diagnostics，全部修复完成
   - 遇到无法确定的问题，需要我介入决策
5. **输出总结**：向我汇报最终结论，必须包含：
   - 已修复的问题清单
   - 未修复的问题及原因（如有）
   - Workaround 说明（如有临时方案或权宜之计）

## 注意事项

1. **输入延迟**：agent TUI 存在 debounce，发送内容后等待约 1 秒发送一次 `C-m`，再等待约 3 秒发送第二次 `C-m` 以确保触发
2. **保持耐心**：此过程可能需要多轮迭代，请从容应对
3. **谨慎修复**：确保修复不会引入新问题或改变原有逻辑]],
    conditional = function()
      local cwd = dot.path.cwd()
      local config_home = vim.env.XDG_CONFIG_HOME or (vim.env.HOME .. "/.config")
      local nvim_config = config_home .. "/nvim"
      local nvchad_config = config_home .. "/nvim-nvchad"
      return cwd == nvim_config or cwd == nvchad_config
    end,
  },
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
