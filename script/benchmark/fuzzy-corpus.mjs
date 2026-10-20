// Deterministic corpora and typing sequences for the fuzzy matcher benchmarks.
import { spawnSync } from "node:child_process"
import { createHash } from "node:crypto"
import { existsSync, mkdirSync, readFileSync, readdirSync, renameSync, writeFileSync } from "node:fs"
import { homedir } from "node:os"
import { dirname, join, relative, resolve, sep } from "node:path"
import { fileURLToPath } from "node:url"
import { parseArgs } from "node:util"

const here = dirname(fileURLToPath(import.meta.url))
const checkout = resolve(here, "../..")

export const SCHEMA_VERSION = 1
export const SEED = 0x5eed1234
export const TARGETS = 24

export const corpusSpecs = [
  { name: "repo", kind: "path", scheme: "path", source: "git ls-files of this checkout" },
  { name: "runtime", kind: "path", scheme: "path", source: "files under $VIMRUNTIME" },
  { name: "plugins", kind: "path", scheme: "path", source: "files under the lazy plugin directory" },
  { name: "synthetic-10k", kind: "path", scheme: "path", count: 10000, source: "generated from real path segments" },
  { name: "synthetic-100k", kind: "path", scheme: "path", count: 100000, source: "generated from real path segments" },
  { name: "synthetic-1m", kind: "path", scheme: "path", count: 1000000, source: "generated from real path segments" },
  { name: "labels", kind: "label", scheme: "default", source: "help tags, options, highlight groups, functions" },
  { name: "labels-100k", kind: "label", scheme: "default", count: 100000, source: "generated from real label tokens" },
  { name: "unicode", kind: "path", scheme: "path", count: 5000, source: "generated paths with CJK and accented segments" },
]

/** Small, fast, seedable PRNG; identical sequences on every platform. */
export function mulberry32(seed) {
  let state = seed >>> 0
  return () => {
    state = (state + 0x6d2b79f5) >>> 0
    let value = state
    value = Math.imul(value ^ (value >>> 15), value | 1)
    value ^= value + Math.imul(value ^ (value >>> 7), value | 61)
    return ((value ^ (value >>> 14)) >>> 0) / 4294967296
  }
}

const pick = (rng, values) => values[Math.floor(rng() * values.length)]

/** Byte order of the UTF-8 encoding, which Rust and Lua string comparison share. */
export function canonical(items) {
  const unique = [...new Set(items)].filter((item) => item !== "" && !/[\t\n\r]/.test(item))
  return unique.map((item) => [Buffer.from(item), item]).sort((a, b) => Buffer.compare(a[0], b[0])).map(([, item]) => item)
}

function walk(root, skip = () => false) {
  const files = []
  const visit = (path) => {
    for (const entry of readdirSync(path, { withFileTypes: true })) {
      const full = join(path, entry.name)
      if (skip(entry.name)) continue
      if (entry.isDirectory()) visit(full)
      else if (entry.isFile()) files.push(relative(root, full).split(sep).join("/"))
    }
  }
  visit(root)
  return files
}

function nvimDump(nvim) {
  const script = [
    "local out = {}",
    "for name in pairs(vim.api.nvim_get_all_options_info()) do out[#out + 1] = name end",
    "for name in pairs(vim.api.nvim_get_hl(0, {})) do out[#out + 1] = name end",
    "for _, name in ipairs(vim.fn.getcompletion('', 'function')) do out[#out + 1] = (name:gsub('%(%)?$', '')) end",
    "for _, line in ipairs(vim.fn.readfile(vim.env.VIMRUNTIME .. '/doc/tags')) do out[#out + 1] = line:match('^[^\\t]+') end",
    "io.stdout:write(vim.env.VIMRUNTIME, '\\n', table.concat(out, '\\n'))",
  ].join("\n")
  const result = spawnSync(nvim, ["--clean", "--headless", "-l", "-"], { input: script, encoding: "utf8", maxBuffer: 1 << 28 })
  if (result.status !== 0) throw new Error(`nvim label dump failed: ${result.stderr}`)
  const [runtime, ...labels] = result.stdout.split("\n")
  return { runtime, labels }
}

function segmentsOf(paths) {
  const dirs = [], stems = [], extensions = []
  for (const path of canonical(paths)) {
    const parts = path.split("/")
    const base = parts.pop()
    dirs.push(...parts)
    const dot = base.lastIndexOf(".")
    stems.push(dot > 0 ? base.slice(0, dot) : base)
    extensions.push(dot > 0 ? base.slice(dot) : "")
  }
  return { dirs, stems, extensions }
}

/** Paths that share directory prefixes the way real trees do. */
export function synthesizePaths(count, pools, rng) {
  const dirs = [""], seen = new Set(), files = new Set()
  const depth = (dir) => (dir === "" ? 0 : dir.split("/").length)
  while (files.size < count) {
    if (dirs.length < 32 || rng() < 0.12) {
      const parent = pick(rng, dirs)
      if (depth(parent) < 7) {
        const dir = parent === "" ? pick(rng, pools.dirs) : `${parent}/${pick(rng, pools.dirs)}`
        if (!seen.has(dir)) { seen.add(dir); dirs.push(dir) }
      }
    }
    // Later directories receive more files, so deep trees stay populated.
    const dir = dirs[Math.floor(Math.sqrt(rng()) * dirs.length)]
    let stem = pick(rng, pools.stems)
    if (rng() < 0.3) stem = `${stem}_${pick(rng, pools.stems)}`
    if (rng() < 0.15) stem = `${stem}${Math.floor(rng() * 100)}`
    const name = `${stem}${pick(rng, pools.extensions)}`
    files.add(dir === "" ? name : `${dir}/${name}`)
  }
  return [...files]
}

export function wordsOf(text) {
  return text.split(/[^A-Za-z0-9\u0080-\u{10FFFF}]+|(?<=[a-z0-9])(?=[A-Z])/u).filter(Boolean)
}

function synthesizeLabels(count, labels, rng) {
  const tokens = canonical(labels.flatMap(wordsOf).filter((token) => token.length > 1))
  const result = new Set()
  const joiners = ["_", "", ".", "-", ":"]
  while (result.size < count) {
    const parts = Array.from({ length: 2 + Math.floor(rng() * 3) }, () => pick(rng, tokens))
    const joiner = pick(rng, joiners)
    result.add(joiner === "" ? parts.map((part, index) => (index ? part[0].toUpperCase() + part.slice(1) : part)).join("") : parts.join(joiner))
  }
  return [...result]
}

const CJK = ["文档", "测试", "配置", "组件", "工具", "数据", "接口", "模块", "页面", "服务", "用户", "设置"]
const ACCENTED = ["café", "résumé", "naïve", "über", "señor", "façade", "crème", "jalapeño", "déjà", "smörgås"]

function synthesizeUnicode(count, pools, rng) {
  const mixed = {
    dirs: [...pools.dirs.slice(0, 2000), ...CJK, ...ACCENTED],
    stems: [...pools.stems.slice(0, 2000), ...CJK, ...ACCENTED, ...CJK.map((word) => `${word}_${pick(rng, ACCENTED)}`)],
    extensions: pools.extensions,
  }
  return synthesizePaths(count, mixed, rng)
}

function stemOf(path) {
  const base = path.split("/").at(-1)
  const dot = base.lastIndexOf(".")
  return dot > 0 ? base.slice(0, dot) : base
}

/** First letters of each word, or every other letter of a single word, as fuzzy users type. */
function abbreviation(words, width) {
  if (words.length > 1) return words.map((word) => [...word].slice(0, 2).join("")).join("").slice(0, width)
  return [...(words[0] ?? "")].filter((_, index) => index % 2 === 0).slice(0, 5).join("")
}

/** Character-by-character typing of a final query. */
function steps(query) {
  return Array.from({ length: [...query].length }, (_, index) => [...query].slice(0, index + 1).join(""))
}

export function sequencesFor(spec, items, rng) {
  const sequences = []
  const add = (kind, target, query) => {
    if (!query || /[\t\n\r]/.test(query)) return
    sequences.push({ id: sequences.length + 1, kind, target, query, steps: steps(query) })
  }
  for (let count = 0; count < TARGETS; count++) {
    const target = Math.floor(rng() * items.length)
    const item = items[target]
    if (spec.kind === "path") {
      const stem = stemOf(item), dirs = item.split("/").slice(0, -1)
      add("stem", target, [...stem].slice(0, 8).join(""))
      add("abbrev", target, abbreviation(wordsOf(stem), 8))
      if (dirs.length) add("path", target, `${[...dirs.at(-1)].slice(0, 3).join("")}/${[...stem].slice(0, 3).join("")}`)
    } else {
      const words = wordsOf(item)
      add("prefix", target, [...item].slice(0, 6).join(""))
      add("abbrev", target, abbreviation(words, 6))
      if (words.length > 1) add("infix", target, [...words.at(-1)].slice(0, 4).join(""))
    }
  }
  add("nomatch", -1, "zqxjv")
  add("nomatch", -1, "qwzqwz")
  for (let count = 0; count < 4; count++) {
    const target = Math.floor(rng() * items.length)
    const item = items[target]
    const other = items[Math.floor(rng() * items.length)]
    const word = (text) => [...(wordsOf(spec.kind === "path" ? stemOf(text) : text)[0] ?? text)].slice(0, 3).join("")
    const first = spec.kind === "path" ? [...item.split("/")[0]].slice(0, 3).join("") : word(item)
    const extension = spec.kind === "path" ? item.match(/\.[^./]+$/)?.[0] : undefined
    add("extended", target, [`${first} ${word(item)}`, `^${first} ${word(item)}`, `${word(item)} !${word(other)}`, `${word(item)} | ${word(other)}`][count])
    if (count === 0 && extension) add("extended", target, `${word(item)} ${extension}$`)
  }
  return sequences
}

function sha256(text) {
  return createHash("sha256").update(text).digest("hex")
}

function writeAtomic(path, text) {
  writeFileSync(`${path}.tmp`, text)
  renameSync(`${path}.tmp`, path)
}

/** Generates every missing corpus under `directory` and returns the manifest. */
export function ensureCorpora(directory, { names = corpusSpecs.map((spec) => spec.name), force = false, nvim = "nvim", lazy = join(homedir(), ".local/share/nvim/lazy") } = {}) {
  mkdirSync(join(directory, "queries"), { recursive: true })
  const manifestPath = join(directory, "manifest.json")
  const manifest = existsSync(manifestPath) && !force ? JSON.parse(readFileSync(manifestPath, "utf8")) : { schema_version: SCHEMA_VERSION, seed: SEED, corpora: {} }
  if (manifest.schema_version !== SCHEMA_VERSION || manifest.seed !== SEED) throw new Error("corpus cache has a different schema or seed; regenerate with --force")
  let dump, real
  const realPaths = () => {
    if (real) return real
    dump ??= nvimDump(nvim)
    real = {
      repo: spawnSync("git", ["-C", checkout, "ls-files", "-z"], { encoding: "utf8", env: { ...process.env, GIT_OPTIONAL_LOCKS: "0" }, maxBuffer: 1 << 28 }).stdout.split("\0").filter(Boolean),
      runtime: walk(dump.runtime),
      plugins: existsSync(lazy) ? walk(lazy, (name) => name === ".git" || name === "node_modules") : [],
    }
    return real
  }
  for (const spec of corpusSpecs.filter((item) => names.includes(item.name))) {
    if (manifest.corpora[spec.name] && existsSync(join(directory, `${spec.name}.txt`)) && !force) continue
    const rng = mulberry32(SEED ^ [...spec.name].reduce((hash, char) => Math.imul(hash, 31) + char.charCodeAt(0), 7))
    let items
    if (["repo", "runtime", "plugins"].includes(spec.name)) items = realPaths()[spec.name]
    else if (spec.name.startsWith("synthetic-")) {
      const paths = realPaths()
      items = synthesizePaths(spec.count, segmentsOf([...paths.repo, ...paths.runtime, ...paths.plugins]), rng)
    } else if (spec.name === "labels") {
      dump ??= nvimDump(nvim)
      items = dump.labels
    } else if (spec.name === "labels-100k") {
      dump ??= nvimDump(nvim)
      items = synthesizeLabels(spec.count, dump.labels, rng)
    } else if (spec.name === "unicode") {
      const paths = realPaths()
      items = synthesizeUnicode(spec.count, segmentsOf([...paths.repo, ...paths.runtime]), rng)
    }
    items = canonical(items)
    if (!items.length) throw new Error(`empty corpus: ${spec.name}`)
    const text = `${items.join("\n")}\n`
    writeAtomic(join(directory, `${spec.name}.txt`), text)
    const sequences = sequencesFor(spec, items, mulberry32(SEED ^ 0x9e3779b9 ^ items.length))
    const rows = sequences.flatMap((sequence) => sequence.steps.map((query, step) => [sequence.id, sequence.kind, sequence.target, step + 1, query].join("\t")))
    writeAtomic(join(directory, "queries", `${spec.name}.tsv`), `${rows.join("\n")}\n`)
    writeAtomic(join(directory, "queries", `${spec.name}.json`), `${JSON.stringify(sequences)}\n`)
    manifest.corpora[spec.name] = {
      kind: spec.kind, scheme: spec.scheme, count: items.length, bytes: Buffer.byteLength(text), source: spec.source,
      sha256: sha256(text), queries_sha256: sha256(rows.join("\n")), sequences: sequences.length, queries: rows.length,
      ascii: items.every((item) => /^[\x00-\x7f]*$/.test(item)),
    }
    writeAtomic(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`)
  }
  const tsv = Object.entries(manifest.corpora).map(([name, entry]) => [name, entry.kind, entry.scheme, entry.count, entry.sha256].join("\t"))
  writeAtomic(join(directory, "manifest.tsv"), `${tsv.join("\n")}\n`)
  return manifest
}

/** Verifies that cached corpora still hash to their manifest entries. */
export function verifyCorpora(directory, names) {
  const manifest = JSON.parse(readFileSync(join(directory, "manifest.json"), "utf8"))
  for (const name of names) {
    const entry = manifest.corpora[name]
    if (!entry) throw new Error(`missing corpus: ${name}`)
    if (sha256(readFileSync(join(directory, `${name}.txt`))) !== entry.sha256) throw new Error(`corpus changed: ${name}`)
  }
  return manifest
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const { values } = parseArgs({ options: {
    out: { type: "string" }, corpus: { type: "string", multiple: true }, force: { type: "boolean" },
    nvim: { type: "string", default: "nvim" }, help: { type: "boolean", short: "h" },
  } })
  if (values.help || !values.out) {
    console.log(`Usage: node ${fileURLToPath(import.meta.url)} --out DIR [--corpus NAME]... [--force]
Corpora: ${corpusSpecs.map((spec) => spec.name).join(", ")}`)
  } else {
    const started = Date.now()
    const manifest = ensureCorpora(resolve(values.out), { names: values.corpus ?? corpusSpecs.map((spec) => spec.name), force: values.force, nvim: values.nvim })
    for (const [name, entry] of Object.entries(manifest.corpora)) {
      console.log(`${name.padEnd(16)} ${String(entry.count).padStart(8)} items ${String(entry.queries).padStart(5)} queries ${entry.ascii ? "ascii" : "unicode"} ${entry.sha256.slice(0, 12)}`)
    }
    console.log(`done in ${((Date.now() - started) / 1000).toFixed(1)}s`)
  }
}
