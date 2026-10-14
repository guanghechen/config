// Run with: node --test __test__/node/cmp-cli.test.mjs
import assert from "node:assert/strict"
import { spawnSync } from "node:child_process"
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { dirname, join } from "node:path"
import test from "node:test"
import { fileURLToPath } from "node:url"

const repository = fileURLToPath(new URL("../../", import.meta.url))

function fixture(t) {
  const root = mkdtempSync(join(tmpdir(), "cmp-cli-test-"))
  t.after(() => rmSync(root, { recursive: true, force: true }))
  const blink = join(root, "blink")
  const baseline = join(root, "era")
  for (const [name, contents] of [
    [join(blink, "lua/blink/cmp/init.lua"), "return {}\n"],
    [join(blink, "lua/blink/cmp/source.lua"), "return { value = 1 }\n"],
    [join(blink, "target/release/libblink_cmp_fuzzy.so"), "blink native fixture"],
    [join(baseline, "lua/era/keystroke/cmp/init.lua"), "return {}\n"],
    [join(baseline, "rust/yoz/src/completion.rs"), "pub fn fixture() {}\n"],
    [join(baseline, "bin/nix.yoz.so"), "era native fixture"],
  ]) {
    mkdirSync(dirname(name), { recursive: true })
    writeFileSync(name, contents)
  }
  return { root, blink, baseline }
}

function lua(root, source, args) {
  const script = join(root, "probe.lua")
  writeFileSync(script, source)
  const result = spawnSync("nvim", ["--headless", "-u", "NONE", "-i", "NONE", "-n", "-l", script, repository, ...args], {
    cwd: repository,
    encoding: "utf8",
    timeout: 15000,
  })
  assert.ifError(result.error)
  assert.equal(result.signal, null)
  return result
}

test("benchmark metadata fingerprints Blink Lua independently of Git and native bytes", (t) => {
  const { root, blink, baseline } = fixture(t)
  const source = `local root, output, blink, baseline = unpack(arg)
package.path = root .. '/?.lua;' .. root .. '/?/init.lua;' .. package.path
package.preload['__test__.bench.cmp.sources'] = function()
  return { run = function() return { cases = {} } end }
end
arg = { output, blink, '5', 'sources', baseline, 'off' }
dofile(root .. '/__test__/bench/cmp.lua')
`
  const firstOutput = join(root, "first")
  const first = lua(root, source, [firstOutput, blink, baseline])
  assert.equal(first.status, 0, first.stderr)
  const before = JSON.parse(readFileSync(join(firstOutput, "metadata.json"), "utf8"))
  assert.match(before.blink_lua_sha256, /^[a-f0-9]{64}$/)
  writeFileSync(join(blink, "lua/blink/cmp/source.lua"), "return { value = 2 }\n")
  const secondOutput = join(root, "second")
  const second = lua(root, source, [secondOutput, blink, baseline])
  assert.equal(second.status, 0, second.stderr)
  const after = JSON.parse(readFileSync(join(secondOutput, "metadata.json"), "utf8"))
  assert.notEqual(after.blink_lua_sha256, before.blink_lua_sha256)
  assert.equal(after.libraries.blink.sha256, before.libraries.blink.sha256)
  assert.equal(after.blink_revision, before.blink_revision)
  assert.equal(after.blink_dirty, before.blink_dirty)
})

test("behavior CLI rejects a filter that matches no case", (t) => {
  const { root, blink, baseline } = fixture(t)
  const output = join(root, "behavior")
  const result = lua(root, `local root, output, blink, baseline = unpack(arg)
arg = { output, blink, '__no_such_behavior_case__', baseline }
dofile(root .. '/__test__/compare/cmp.lua')
`, [output, blink, baseline])
  assert.equal(result.status, 1, result.stderr)
  assert.match(result.stderr, /no behavior cases matched filter/)
  assert.doesNotMatch(result.stdout, /Results:/)
  assert.equal(existsSync(join(output, "behavior.json")), false)
})

test("native load CLI rejects a filter that matches no scenario", (t) => {
  const { root, baseline } = fixture(t)
  const output = join(root, "load")
  const result = lua(root, `local root, output, baseline = unpack(arg)
arg = { output, baseline, '5', 'load', '__no_such_load_case__' }
dofile(root .. '/__test__/bench/cmp_native.lua')
`, [output, baseline])
  assert.equal(result.status, 1, result.stderr)
  assert.match(result.stderr, /no load scenarios matched filter/)
  assert.doesNotMatch(result.stdout, /Results:/)
  assert.equal(existsSync(join(output, "load.json")), false)
})
