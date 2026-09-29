import assert from "node:assert/strict"
import { mkdirSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import test from "node:test"

import { inspectArtifact, nativeInputs, pluginInputs, runtimeInputs, writeBuildReceipt } from "../../script/benchmark/provenance.mjs"

function fixture(t) {
  const root = mkdtempSync(join(tmpdir(), "input-provenance-test-"))
  t.after(() => rmSync(root, { recursive: true, force: true }))
  for (const folder of ["rust/yoz/src", "rust/target", "lua", ".cargo"]) mkdirSync(join(root, folder), { recursive: true })
  writeFileSync(join(root, "rust/Cargo.toml"), "[workspace]\n")
  writeFileSync(join(root, "rust/yoz/src/lib.rs"), "pub fn identity() {}\n")
  writeFileSync(join(root, "lua/init.lua"), "return {}\n")
  const artifact = join(root, "lua/yoz.so")
  writeFileSync(artifact, "native artifact")
  return { root, artifact }
}

test("receipt binds the deployed artifact to native contents while runtime changes stay independent", (t) => {
  const { root, artifact } = fixture(t)
  const source = nativeInputs(root)
  const runtime = runtimeInputs(root)
  writeBuildReceipt(artifact, source, { profile: "release" })
  assert.equal(inspectArtifact(root, artifact).status, "verified")
  writeFileSync(join(root, "rust/target/generated"), "compiler output")
  assert.equal(nativeInputs(root).sha256, source.sha256)
  writeFileSync(join(root, "lua/init.lua"), "return { changed = true }\n")
  assert.notEqual(runtimeInputs(root).sha256, runtime.sha256)
  assert.equal(inspectArtifact(root, artifact).status, "verified")
  writeFileSync(join(root, "rust/yoz/src/lib.rs"), "pub fn changed() {}\n")
  assert.equal(inspectArtifact(root, artifact).status, "mismatch")
})

test("an artifact replacement cannot reuse a matching source receipt", (t) => {
  const { root, artifact } = fixture(t)
  writeBuildReceipt(artifact, nativeInputs(root), { profile: "release" })
  writeFileSync(artifact, "different library with the same source checkout")
  assert.equal(inspectArtifact(root, artifact).status, "mismatch")
})

test("missing and corrupt receipts are explicitly unverified", (t) => {
  const { root, artifact } = fixture(t)
  assert.equal(inspectArtifact(root, artifact).status, "unverified")
  writeFileSync(`${artifact}.build.json`, "incomplete JSON")
  assert.equal(inspectArtifact(root, artifact).status, "unverified")
})

test("plugin snapshots include ignored native libraries and repeated dirty runtime edits", (t) => {
  const { root } = fixture(t)
  mkdirSync(join(root, "target/release"), { recursive: true })
  mkdirSync(join(root, "plugin"))
  const library = join(root, "target/release/libplugin.dylib")
  const runtime = join(root, "plugin/setup.vim")
  writeFileSync(join(root, ".gitignore"), "/target\n")
  writeFileSync(library, "first native library")
  writeFileSync(runtime, "let g:plugin = 1\n")
  const first = pluginInputs(root)
  assert.ok(first.files["target/release/libplugin.dylib"])
  writeFileSync(library, "rebuilt native library")
  const rebuilt = pluginInputs(root)
  assert.notEqual(rebuilt.sha256, first.sha256)
  writeFileSync(runtime, "let g:plugin = 2\n")
  const dirty = pluginInputs(root)
  writeFileSync(runtime, "let g:plugin = 3\n")
  assert.notEqual(pluginInputs(root).sha256, dirty.sha256)
  mkdirSync(join(root, "rust/target/release"), { recursive: true })
  writeFileSync(join(root, "rust/target/release/libnested.dylib"), "nested plugin library")
  assert.ok(pluginInputs(root).files["rust/target/release/libnested.dylib"])
})

test("runtime directories behind symlinks cannot silently disappear from a fingerprint", (t) => {
  const { root } = fixture(t)
  mkdirSync(join(root, "external"))
  writeFileSync(join(root, "external/entry.lua"), "return 1\n")
  rmSync(join(root, "lua"), { recursive: true })
  symlinkSync(join(root, "external"), join(root, "lua"), "junction")
  assert.throws(() => runtimeInputs(root), /must not be a symlink: lua/)
  assert.throws(() => pluginInputs(root), /must not be a symlink: lua/)
})
