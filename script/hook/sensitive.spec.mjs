import assert from "node:assert/strict"
import { spawnSync } from "node:child_process"
import path from "node:path"
import { fileURLToPath } from "node:url"
import { test } from "node:test"
import { isSensitiveFile } from "../util.mjs"

const hookDirectory = path.dirname(fileURLToPath(import.meta.url))

test("classifies credential files and exact env templates", () => {
  for (const filepath of [
    "/fixture/auth.json",
    "/fixture/.env",
    "/fixture/.env.local",
    "/fixture/.env.production",
    "/fixture/.env.example.local",
    "/fixture/.git-credentials",
    "/fixture/request.http_request",
    "/fixture/response.http_response",
    "/fixture/.ssh/config",
  ]) {
    assert.equal(isSensitiveFile(filepath), true, filepath)
  }

  for (const filepath of [
    "/fixture/.env.example",
    "/fixture/.env.sample",
    "/fixture/.env.template",
    "/fixture/auth.json.example",
    "/fixture/config.toml",
  ]) {
    assert.equal(isSensitiveFile(filepath), false, filepath)
  }
})

test("Bash hook blocks auth.json and permits exact env templates", () => {
  const denied = runHook("pre-bash-sensitive.mjs", {
    tool_name: "Bash",
    tool_input: { command: "env MODE=audit cat /fixture/auth.json" },
  })
  assert.equal(denied.hookSpecificOutput.permissionDecision, "deny")
  assert.match(denied.hookSpecificOutput.permissionDecisionReason, /auth\.json/)

  const allowed = runHook("pre-bash-sensitive.mjs", {
    tool_name: "Bash",
    tool_input: { command: "cat /fixture/.env.example" },
  })
  assert.equal(allowed, null)
})

test("apply_patch hook blocks auth.json and permits exact env templates", () => {
  const denied = runHook("pre-tool-use.mjs", patchInput("auth.json"))
  assert.equal(denied.hookSpecificOutput.permissionDecision, "deny")
  assert.match(denied.hookSpecificOutput.permissionDecisionReason, /auth\.json/)

  const allowed = runHook("pre-tool-use.mjs", patchInput(".env.template"))
  assert.equal(allowed, null)
})

function patchInput(filepath) {
  return {
    tool_name: "apply_patch",
    tool_input: {
      command: [
        "*** Begin Patch",
        `*** Update File: ${filepath}`,
        "*** End Patch",
      ].join("\n"),
    },
  }
}

function runHook(scriptName, input) {
  const result = spawnSync(process.execPath, [path.join(hookDirectory, scriptName)], {
    encoding: "utf8",
    input: JSON.stringify(input),
  })
  assert.equal(result.status, 0, result.stderr)

  const output = result.stdout.trim()
  return output.length === 0 ? null : JSON.parse(output)
}
