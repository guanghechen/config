import assert from "node:assert/strict"
import { spawnSync } from "node:child_process"
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { dirname, join } from "node:path"
import test from "node:test"
import { fileURLToPath } from "node:url"

const repository = fileURLToPath(new URL("../../", import.meta.url))
const library = process.platform === "win32" ? "lua/yoz.dll" : "lua/yoz.so"

function fixture(t) {
  const root = mkdtempSync(join(tmpdir(), "cmp-cli-test-"))
  t.after(() => rmSync(root, { recursive: true, force: true }))
  const baseline = join(root, "era")
  for (const [name, contents] of [
    [join(baseline, "lua/era/keystroke/cmp/init.lua"), "return {}\n"],
    [join(baseline, "rust/yoz/src/completion.rs"), "pub fn fixture() {}\n"],
    [join(baseline, library), "era native fixture"],
  ]) {
    mkdirSync(dirname(name), { recursive: true })
    writeFileSync(name, contents)
  }
  return { root, baseline }
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

test("benchmark metadata fingerprints the baseline's native library and completion sources separately", (t) => {
  const { root, baseline } = fixture(t)
  const source = `local root, output, baseline = unpack(arg)
package.path = root .. '/?.lua;' .. root .. '/?/init.lua;' .. package.path
package.preload['__test__.bench.cmp.ranking'] = function()
  return { run = function() return {} end }
end
arg = { output, baseline, '5', 'ranking' }
dofile(root .. '/__test__/bench/cmp.lua')
`
  const metadata = (name) => {
    const output = join(root, name)
    const result = lua(root, source, [output, baseline])
    assert.equal(result.status, 0, result.stderr)
    return JSON.parse(readFileSync(join(output, "metadata.json"), "utf8"))
  }
  const before = metadata("first")
  assert.match(before.native_sha256, /^[a-f0-9]{64}$/)
  writeFileSync(join(baseline, library), "rebuilt era native fixture")
  const rebuilt = metadata("second")
  assert.notEqual(rebuilt.native_sha256, before.native_sha256)
  assert.equal(rebuilt.completion_lua_sha256, before.completion_lua_sha256)
  writeFileSync(join(baseline, "lua/era/keystroke/cmp/init.lua"), "return { changed = true }\n")
  const edited = metadata("third")
  assert.notEqual(edited.completion_lua_sha256, rebuilt.completion_lua_sha256)
  assert.equal(edited.native_sha256, rebuilt.native_sha256)
})

test("load CLI rejects a filter that matches no scenario", (t) => {
  const { root, baseline } = fixture(t)
  const output = join(root, "load")
  const result = lua(root, `local root, output, baseline = unpack(arg)
arg = { output, baseline, '5', 'load', '__no_such_load_case__' }
dofile(root .. '/__test__/bench/cmp.lua')
`, [output, baseline])
  assert.equal(result.status, 1, result.stderr)
  assert.match(result.stderr, /no load scenarios matched filter/)
  assert.doesNotMatch(result.stdout, /Results:/)
  assert.equal(existsSync(join(output, "load.json")), false)
})
