// Run with: node --test __test__/node/healcheck.test.mjs
import assert from "node:assert/strict"
import test from "node:test"

import { CROSS_TARGETS, selectCrossTargets } from "../../script/healcheck.mjs"

test("selectCrossTargets keeps the installed platform targets other than the host", () => {
  const installed = ["aarch64-apple-darwin", "wasm32-unknown-unknown", "x86_64-pc-windows-msvc", ""].join("\r\n")

  assert.deepEqual(selectCrossTargets("aarch64-apple-darwin\n", installed), ["x86_64-pc-windows-msvc"])
})

test("selectCrossTargets keeps the host platform on another architecture", () => {
  assert.deepEqual(selectCrossTargets("x86_64-apple-darwin\n", CROSS_TARGETS.join("\n")), CROSS_TARGETS)
})

test("selectCrossTargets selects nothing when only the host is installed", () => {
  assert.deepEqual(selectCrossTargets("x86_64-unknown-linux-gnu\n", "x86_64-unknown-linux-gnu\n"), [])
})
