import assert from "node:assert/strict"
import { spawnSync } from "node:child_process"
import { mkdtempSync, readFileSync, rmSync, symlinkSync } from "node:fs"
import { tmpdir } from "node:os"
import path from "node:path"
import test from "node:test"
import { fileURLToPath } from "node:url"
import { isSensitiveFile } from "./sensitive.mjs"

const configDir = fileURLToPath(new URL("../../", import.meta.url))
const settings = JSON.parse(readFileSync(path.join(configDir, "settings.json"), "utf8"))
const envFiles = [
  ".env", ".env.local", ".env.production", ".envrc", ".environment",
  ".env.sample", ".env.template", ".env.example.local", ".env.sample.bak",
]
const envTemplate = ".env.example"

function runGuard(script, toolName, toolInput) {
  // Commands and paths are synthetic input; the guard never executes or opens them.
  const result = spawnSync(process.execPath, [fileURLToPath(new URL(script, import.meta.url))], {
    input: JSON.stringify({ tool_name: toolName, tool_input: toolInput }),
    encoding: "utf8",
    timeout: 5000,
  })
  assert.equal(result.status, 0, result.stderr)
  return result.stdout.trim() ? JSON.parse(result.stdout).hookSpecificOutput : undefined
}

test("ordinary Bash and unguarded git commands do not receive blanket approval", () => {
  for (const command of ["printf hello", "git status", "git clean -fd", "git commit -m example"]) {
    for (const script of ["pre-bash-sensitive.mjs", "pre-bash-git.mjs"]) {
      assert.equal(runGuard(script, "Bash", { command }), undefined, `${script}: ${command}`)
    }
  }
})

test("explicit git guard decisions remain intact", () => {
  for (const command of [
    "git push origin main",
    "git -C /synthetic/project reset --hard HEAD",
    "git --work-tree /synthetic/project revert HEAD",
    "git commit --amend",
  ]) {
    assert.equal(runGuard("pre-bash-git.mjs", "Bash", { command }).permissionDecision, "ask", command)
  }
})

test("environment files are blocked except the .env.example template", () => {
  for (const name of envFiles) {
    const file = `/synthetic/project/${name}`
    assert.equal(isSensitiveFile(file), true, file)
    assert.equal(runGuard("pre-bash-sensitive.mjs", "Bash", { command: `cat ${file}` }).permissionDecision, "deny")
  }
  const template = `/synthetic/project/${envTemplate}`
  assert.equal(isSensitiveFile(template), false)
  assert.equal(runGuard("pre-bash-sensitive.mjs", "Bash", { command: `cat ${template}` }), undefined)
})

test("protected directories and other sensitive paths remain blocked", () => {
  for (const file of [
    "/synthetic/.ssh", "/synthetic/.credentials",
    "/synthetic/.ssh/.env.example", "/synthetic/.credentials/.env.sample",
    "/synthetic/.env.template/private.txt", "/synthetic/.env.local/.env.example",
    "/synthetic/local/env.example", "/synthetic/local/config.fish", "/synthetic/local/config.ps1",
    "/synthetic/.git-credentials", "/synthetic/request.http_request", "/synthetic/response.http_response",
    "C:\\synthetic\\.credentials\\.env.template", "C:\\synthetic\\.env.production",
  ]) assert.equal(isSensitiveFile(file), true, file)
  assert.equal(isSensitiveFile("C:\\synthetic\\.env.example"), false)
})

test("plaintext Claude credential store is blocked", () => {
  for (const file of ["/synthetic/.claude/.credentials.json", "C:\\synthetic\\.claude\\.credentials.json"]) {
    assert.equal(isSensitiveFile(file), true, file)
  }
  assert.equal(isSensitiveFile("/synthetic/credentials.json"), false)
  const command = "cat /synthetic/.claude/.credentials.json"
  assert.equal(runGuard("pre-bash-sensitive.mjs", "Bash", { command }).permissionDecision, "deny")
  for (const tool of ["Read", "Edit"]) {
    assert.ok(settings.permissions.deny.includes(`${tool}(//**/.credentials.json)`), tool)
  }
})

function deniedAnywhere(tool, name) {
  const prefix = `${tool}(//**/`
  return settings.permissions.deny.some(
    (rule) => rule.startsWith(prefix) && path.matchesGlob(name, rule.slice(prefix.length, -1)),
  )
}

// Mirrors Claude Code: a `!` rule carves its matches out of the relative rules listed before it,
// and never out of `//` rules, which are evaluated on their own.
function deniedInProject(tool, name) {
  let denied = false
  for (const rule of settings.permissions.deny) {
    if (!rule.startsWith(`${tool}(`) || rule.startsWith(`${tool}(//`)) continue
    const pattern = rule.slice(tool.length + 1, -1)
    if (pattern.startsWith("!")) {
      if (path.matchesGlob(name, pattern.slice(1))) denied = false
    } else if (path.matchesGlob(name, pattern)) {
      denied = true
    }
  }
  return denied || deniedAnywhere(tool, name)
}

test("Read and Edit rules block env files and leave only .env.example readable", () => {
  for (const tool of ["Read", "Edit"]) {
    for (const name of envFiles) assert.equal(deniedInProject(tool, name), true, `${tool}: ${name}`)
    for (const name of ["README.md", "config.mjs", "env.example"]) {
      assert.equal(deniedInProject(tool, name), false, `${tool}: ${name}`)
    }
  }
  assert.equal(deniedInProject("Read", envTemplate), false)
  assert.equal(deniedInProject("Edit", envTemplate), true)
  // Outside the project only `//` rules apply, so they must still cover the common secret names.
  for (const name of [
    ".env", ".env.local", ".env.production.local", ".env.production",
    ".env.development", ".env.staging", ".env.test", ".envrc",
  ]) assert.equal(deniedAnywhere("Read", name), true, name)
  assert.equal(deniedAnywhere("Read", envTemplate), false)
})

test("search patterns and glob option values are not mistaken for files", () => {
  for (const command of [
    "rg --fixed-strings .env.example README.md",
    "rg --fixed-strings .env.production README.md",
    "rg -e .env.production README.md",
    "rg --regexp=.env.production README.md",
    "rg -g .env.production pattern README.md",
    "rg --glob .env.production pattern README.md",
    "rg -C 3 .env.production README.md",
    "rg -- .env.production README.md",
    "rg -r .env.production pattern README.md",
    "rg README.md -e .env.production",
    "grep -E .env.production README.md",
    "grep -r --include .env.production pattern docs",
  ]) assert.equal(runGuard("pre-bash-sensitive.mjs", "Bash", { command }), undefined, command)
})

test("search file operands and files containing patterns remain protected", () => {
  for (const command of [
    "rg pattern /synthetic/.env.production",
    "rg -e pattern /synthetic/.env.production",
    "rg /synthetic/.env.production -e pattern",
    "rg -nepattern /synthetic/.env.production",
    "rg -g '*.ts' pattern /synthetic/.env.production",
    "rg -- pattern /synthetic/.env.production",
    "rg -f /synthetic/.env.production README.md",
    "rg -f/synthetic/.env.production README.md",
    "rg --file=/synthetic/.env.production README.md",
    "grep --exclude-from=/synthetic/.env.production pattern README.md",
    "grep -Er pattern /synthetic/.env.production",
    "env TASK_MODE=test timeout 5 rg pattern /synthetic/.env.production",
    "bash -c 'rg pattern /synthetic/.env.production'",
  ]) {
    assert.equal(runGuard("pre-bash-sensitive.mjs", "Bash", { command }).permissionDecision, "deny", command)
  }
})

test("configured policy launchers use CLAUDE_CONFIG_DIR and block load or input failures", () => {
  const temporaryDir = mkdtempSync(path.join(tmpdir(), "claude hook config "))
  try {
    symlinkSync(path.join(configDir, "script"), path.join(temporaryDir, "script"), "dir")
    const env = { ...process.env, CLAUDE_CONFIG_DIR: temporaryDir }
    delete env.XDG_CONFIG_HOME
    for (const entry of settings.hooks.PreToolUse.filter((item) => item.matcher === "Bash")) {
      for (const hook of entry.hooks) {
        const run = (input, configPath = temporaryDir) => spawnSync("sh", ["-c", hook.command], {
          input,
          encoding: "utf8",
          env: { ...env, CLAUDE_CONFIG_DIR: configPath },
          timeout: 5000,
        })
        const valid = JSON.stringify({ tool_name: "Bash", tool_input: { command: "printf hello" } })
        const neutral = run(valid)
        assert.equal(neutral.status, 0, neutral.stderr)
        assert.equal(neutral.stdout, "")
        for (const failed of [run("{"), run(valid, path.join(temporaryDir, "missing"))]) {
          assert.equal(failed.status, 2, failed.stderr)
          assert.ok(failed.stderr.trim(), "the launcher should explain the failure")
        }
      }
    }
  } finally {
    rmSync(temporaryDir, { recursive: true, force: true })
  }
})
