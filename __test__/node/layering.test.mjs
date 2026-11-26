import assert from "node:assert/strict"
import { spawnSync } from "node:child_process"
import { existsSync, readFileSync } from "node:fs"
import { join } from "node:path"
import test from "node:test"
import { fileURLToPath } from "node:url"

const repository = fileURLToPath(new URL("../../", import.meta.url))

// spec/ARCHITECTURE.md: yoz -> stl -> dot -> era -> ark, with ux beside dot on yoz and stl only. Each layer's code and
// type declarations live in its directories, and none of them names a namespace the layer may not depend on.
const LAYERS = [
  { name: "yoz", dirs: ["lua/__types__/yoz"], forbidden: ["stl", "ux", "dot", "era", "ark"] },
  { name: "stl", dirs: ["lua/stl", "lua/__types__/stl"], forbidden: ["ux", "dot", "era", "ark"] },
  { name: "dot", dirs: ["lua/dot", "lua/__types__/dot"], forbidden: ["ux", "era", "ark"] },
  { name: "ux", dirs: ["lua/ux", "lua/__types__/ux"], forbidden: ["dot", "era", "ark"] },
  { name: "era", dirs: ["lua/era", "lua/__types__/era"], forbidden: ["ark"] },
  { name: "ark", dirs: ["lua/ark", "lua/__types__/ark"], forbidden: [] },
]

const DECLARATION = /^\s*---\s*@(?:class|alias|enum)\s+(?:\([^)]*\)\s*)?(\w+)/

// A namespace named as a module or global: `dot.win`, `require("dot.win")` and `dot["win"]`; `_G.dot`, `_G["dot"]`
// and the same through `package.loaded`; `require("dot")` and `rawget(_G, "dot")`.
function referencePattern(namespaces) {
  const name = `(?:${namespaces.join("|")})`
  const forms = [
    `(?<![\\w.])${name}(?:\\.[A-Za-z_][\\w.]*|\\[)`,
    `\\b(?:_G|package\\.loaded)\\s*(?:\\.|\\[\\s*["'])${name}\\b`,
    `\\b(?:require\\s*\\(?|rawget\\s*\\(\\s*_G\\s*,)\\s*["']${name}["']`,
  ]
  return new RegExp(forms.join("|"), "g")
}

// Lua files Git tracks or would track, as luals-check lists them, so ignored local copies cannot fail the check. Git
// lists repository-relative paths with forward slashes on every platform.
function checkoutLuaFiles() {
  const args = ["ls-files", "-z", "--cached", "--others", "--exclude-standard", "--", "*.lua"]
  const result = spawnSync("git", args, { cwd: repository, encoding: "utf8" })
  assert.equal(result.status, 0, result.stderr)
  return result.stdout.split("\0").filter((file) => file && existsSync(join(repository, file)))
}

function lines(file) {
  return readFileSync(join(repository, file), "utf8").split("\n")
}

function owner(file) {
  return LAYERS.find((layer) => layer.dirs.some((dir) => file.startsWith(`${dir}/`)))
}

test("no layer names a namespace it may not depend on, in code or type declarations", () => {
  const checkout = checkoutLuaFiles()
  const violations = []
  for (const layer of LAYERS.filter((entry) => entry.forbidden.length > 0)) {
    const pattern = referencePattern(layer.forbidden)
    const files = checkout.filter((file) => layer.dirs.some((dir) => file.startsWith(`${dir}/`)))
    assert.ok(files.length > 0, `${layer.name} has Lua files`)
    for (const file of files) {
      lines(file).forEach((line, index) => {
        for (const [reference] of line.matchAll(pattern)) {
          violations.push(`${file}:${index + 1}: ${reference}`)
        }
      })
    }
  }
  assert.deepEqual(violations, [])
})

test("a layer's types are declared in that layer's directories", () => {
  const misplaced = []
  // Tests declare their own types under the namespaces they test.
  for (const file of checkoutLuaFiles().filter((path) => !path.startsWith("__test__/"))) {
    lines(file).forEach((line, index) => {
      const namespace = line.match(DECLARATION)?.[1]
      const layer = LAYERS.find((entry) => entry.name === namespace)
      if (layer && owner(file) !== layer) misplaced.push(`${file}:${index + 1}: ${line}`)
    })
  }
  assert.deepEqual(misplaced, [])
})
