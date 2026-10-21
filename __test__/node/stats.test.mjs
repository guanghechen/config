// Run with: node --test __test__/node/stats.test.mjs
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import test from "node:test"

import { summary } from "../../script/benchmark/stats.mjs"

const cases = JSON.parse(readFileSync(new URL("../fixtures/bench/stats_cases.json", import.meta.url), "utf8"))

for (const item of cases) {
  test(`summary matches the shared statistics fixture: ${item.name}`, () => {
    const values = [...item.values]
    assert.deepEqual(summary(values) ?? null, item.summary)
    assert.deepEqual(values, item.values, "input left unchanged")
  })
}
