// Run with: node --test __test__/node/luals-check.test.mjs
import assert from "node:assert/strict"
import { join } from "node:path"
import test from "node:test"
import { pathToFileURL } from "node:url"

import {
  LUALS_VERSION,
  checkSilent,
  checkVersion,
  collectDiagnostics,
  formatDiagnostic,
} from "../../script/luals-check.mjs"

const workspace = "/tmp/luals workspace"

function diagnostic(line, character, severity, message, code = "need-check-nil") {
  return { range: { start: { line, character } }, severity, code, message }
}

test("collectDiagnostics keeps Warning and Error with workspace-relative 1-based positions", () => {
  const report = {
    [pathToFileURL(join(workspace, "lua/b.lua")).href]: [diagnostic(4, 2, 2, "Need check nil.")],
    [pathToFileURL(join(workspace, "lua/a b.lua")).href]: [
      diagnostic(9, 0, 1, "Undefined global `x`.\nmore detail", "undefined-global"),
      diagnostic(1, 0, 3, "Unknown word"),
      diagnostic(0, 3, 2, "Need check nil."),
    ],
  }

  assert.deepEqual(collectDiagnostics(report, workspace), [
    {
      filepath: "lua/a b.lua",
      line: 1,
      col: 4,
      severity: "Warning",
      code: "need-check-nil",
      message: "Need check nil.",
    },
    {
      filepath: "lua/a b.lua",
      line: 10,
      col: 1,
      severity: "Error",
      code: "undefined-global",
      message: "Undefined global `x`.",
    },
    { filepath: "lua/b.lua", line: 5, col: 3, severity: "Warning", code: "need-check-nil", message: "Need check nil." },
  ])
})

test("collectDiagnostics treats the empty report as clean", () => {
  assert.deepEqual(collectDiagnostics([], workspace), [])
})

test("formatDiagnostic prints a navigable location", () => {
  assert.equal(
    formatDiagnostic({
      filepath: "lua/a.lua",
      line: 3,
      col: 7,
      severity: "Warning",
      code: "cast-local-type",
      message: "Cannot convert.",
    }),
    "lua/a.lua:3:7: [Warning] cast-local-type: Cannot convert.",
  )
})

test("checkVersion accepts only the pinned lua-language-server", () => {
  assert.equal(checkVersion(`${LUALS_VERSION}\n`), LUALS_VERSION)
  assert.throws(() => checkVersion("0.0.1\n"), (error) => {
    assert.match(error.message, /0\.0\.1 does not match the pinned/)
    assert.ok(error.message.includes(`:MasonInstall lua-language-server@${LUALS_VERSION}`))
    return true
  })
})

test("checkSilent fails on any LuaLS output so a partial report cannot pass", () => {
  assert.doesNotThrow(() => checkSilent({ stdout: "", stderr: "\n" }))
  assert.throws(() => checkSilent({ stdout: "two hours later\nstack traceback:", stderr: "" }), /failed:\ntwo hours/)
  assert.throws(() => checkSilent({ stdout: "", stderr: "[error] checker: boom" }), /failed:\n\[error\] checker/)
})
