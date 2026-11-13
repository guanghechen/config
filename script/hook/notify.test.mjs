import assert from "node:assert/strict"
import { spawnSync } from "node:child_process"
import { chmodSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import path from "node:path"
import test, { after } from "node:test"
import { fileURLToPath } from "node:url"

const script = fileURLToPath(new URL("notify.mjs", import.meta.url))

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
