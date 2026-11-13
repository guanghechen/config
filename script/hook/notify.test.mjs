import assert from "node:assert/strict"
import { spawnSync } from "node:child_process"
import { chmodSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import path from "node:path"
import test, { after } from "node:test"
import { fileURLToPath } from "node:url"

const script = fileURLToPath(new URL("notify.mjs", import.meta.url))
const configDir = fileURLToPath(new URL("../../", import.meta.url))
const settings = JSON.parse(readFileSync(path.join(configDir, "settings.json"), "utf8"))

// Stub `tmux` and `ps` name `/dev/..` plus the file in $TMUX_TTY or $PS_TTY as the pane tty,
// so each lookup path rings its own file and no real terminal or tmux server is touched.
// Both run once up front, because the first exec of a new script can outlast the hook's
// 1s timeouts. The hook splits `ps` output on whitespace, so paths must not contain spaces.
const stubBin = mkdtempSync(path.join(tmpdir(), "claude-notify-stub-"))
writeFileSync(path.join(stubBin, "tmux"), '#!/bin/sh\necho "/dev/..$TMUX_TTY"\n')
writeFileSync(path.join(stubBin, "ps"), '#!/bin/sh\necho "1 ..$PS_TTY"\n')
for (const name of ["tmux", "ps"]) {
  chmodSync(path.join(stubBin, name), 0o755)
  spawnSync(path.join(stubBin, name))
}
after(() => rmSync(stubBin, { recursive: true, force: true }))

function ring(env) {
  const dir = mkdtempSync(path.join(tmpdir(), "claude-notify-hook-"))
  try {
    const ttys = { tmux: path.join(dir, "tmux-tty"), ps: path.join(dir, "ps-tty") }
    const { TMUX, TMUX_PANE, ...base } = process.env
    const result = spawnSync(process.execPath, [script], {
      encoding: "utf8",
      env: { ...base, PATH: `${stubBin}:${process.env.PATH}`, TMUX_TTY: ttys.tmux, PS_TTY: ttys.ps, ...env },
      timeout: 5000,
    })
    assert.equal(result.status, 0, result.stderr)
    const read = (file) => {
      try {
        return readFileSync(file, "utf8")
      } catch {
        return undefined
      }
    }
    return { tmux: read(ttys.tmux), ps: read(ttys.ps) }
  } finally {
    rmSync(dir, { recursive: true, force: true })
  }
}

test("inside tmux the bell rings the pane's tty", () => {
  assert.deepEqual(ring({ TMUX: "/tmp/stub,1,0", TMUX_PANE: "%0" }), { tmux: "\x07", ps: undefined })
})

test("outside tmux the bell rings the terminal Claude runs in", () => {
  assert.deepEqual(ring({}), { tmux: undefined, ps: "\x07" })
})

test("the bell rings for notifications that need the user and stays quiet for receipts", () => {
  const groups = settings.hooks.Notification.filter((group) => group.hooks.some((hook) => hook.command.includes("notify.mjs")))
  assert.equal(groups.length, 1)
  const matcher = new RegExp(groups[0].matcher)
  // Unknown types ring too, so a notification type added by a later Claude Code is heard.
  const loud = [
    "permission_prompt", "worker_permission_prompt", "agent_needs_input", "agent_completed",
    "elicitation_dialog", "elicitation_url_dialog", "push_notification", "auth_storage_failure",
    "quota_auto_resume_stale", "quota_auto_resume_disabled", "computer_use_enter", "plugin_notification",
    "model_refusal_fallback", "future_notification",
  ]
  const quiet = [
    "idle_prompt", "auth_success", "elicitation_response", "elicitation_complete", "computer_use_exit",
    "quota_auto_resume_fired",
  ]
  for (const type of loud) assert.ok(matcher.test(type), type)
  for (const type of quiet) assert.ok(!matcher.test(type), type)
})
