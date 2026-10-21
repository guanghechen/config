// Run with: node --test __test__/node/format-check.test.mjs
import assert from "node:assert/strict"
import test from "node:test"

import { STYLUA_VERSION, checkStyluaVersion } from "../../script/format-check.mjs"

test("checkStyluaVersion accepts only the pinned StyLua", () => {
  assert.equal(checkStyluaVersion(`stylua ${STYLUA_VERSION}\n`), STYLUA_VERSION)
  assert.throws(() => checkStyluaVersion("stylua 0.0.1\n"), (error) => {
    assert.match(error.message, /stylua 0\.0\.1 does not match the pinned/)
    assert.ok(error.message.includes(`:MasonInstall stylua@${STYLUA_VERSION}`))
    return true
  })
  assert.throws(() => checkStyluaVersion(""), /stylua \(unknown\) does not match/)
})
