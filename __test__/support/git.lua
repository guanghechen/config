---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.git" ---@type string

-- Git runs with a fixed identity and without the user's commit signing or hooks, so fixtures neither depend on
-- nor touch the user's setup. Line-ending and fsmonitor settings are repository config, so a case may change them.
local ISOLATION = {
  "-c",
  "user.name=Test",
  "-c",
  "user.email=test@example.com",
  "-c",
  "commit.gpgSign=false",
  "-c",
  "tag.gpgSign=false",
  "-c",
  "core.hooksPath=" .. (vim.fn.has("win32") == 1 and "NUL" or "/dev/null"),
} ---@type string[]

local M = {}

---@param root                          string
---@param args                          string[]
---@param input                         ?string
---@return vim.SystemCompleted
function M.system(root, args, input)
  local command = vim.list_extend({ "git", "-C", root }, ISOLATION)
  return vim.system(vim.list_extend(command, args), { stdin = input, text = false }):wait(30000)
end

---Runs git and returns its stdout; a nonzero exit raises with git's stderr.
---@param root                          string
---@param args                          string[]
---@param input                         ?string
---@return string
function M.run(root, args, input)
  local result = M.system(root, args, input)
  if result.code ~= 0 then
    error(string.format("git %s: exit %d: %s", table.concat(args, " "), result.code, result.stderr or ""), 2)
  end
  return result.stdout or ""
end

---Creates a repository in a fresh temporary directory that is removed when the case ends.
---@param t                             __test__.support.Harness
---@param init                          ?string[]
---@return string
function M.repo(t, init)
  local root = t:tempdir()
  M.run(root, vim.list_extend({ "init", "-q" }, init or {}))
  M.run(root, { "config", "core.autocrlf", "false" })
  M.run(root, { "config", "core.fsmonitor", "false" })
  return root
end

return M
