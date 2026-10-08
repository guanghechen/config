// Build and benchmark input fingerprints and native build receipts.
import { createHash } from "node:crypto"
import { existsSync, lstatSync, readFileSync, readdirSync, realpathSync, writeFileSync } from "node:fs"
import { basename, join, relative, sep } from "node:path"

export function fileHash(path) {
  return createHash("sha256").update(readFileSync(path)).digest("hex")
}

function fingerprint(root, folders, include, excluded = []) {
  root = realpathSync(root)
  const files = {}
  function visit(path) {
    const name = relative(root, path).split(sep).join("/")
    if (excluded.includes(name) || basename(path) === ".git" || basename(path) === ".DS_Store") return
    if (/(^|\/)(?:\.ssh|\.credentials|\.env[^/]*|\.git-credentials)(?:\/|$)|(^|\/)local\/env\.|\.(?:http_request|http_response)$/.test(name)) {
      if (include(name)) throw new Error(`cannot fingerprint protected input: ${name}`)
      return
    }
    const stat = lstatSync(path)
    if (stat.isSymbolicLink()) throw new Error(`build/runtime input must not be a symlink: ${name}`)
    if (stat.isDirectory()) {
      for (const entry of readdirSync(path).sort()) visit(join(path, entry))
    } else if (stat.isFile() && include(name)) {
      files[name] = fileHash(path)
    }
  }
  for (const folder of folders) {
    const path = join(root, folder)
    if (existsSync(path)) visit(path)
  }
  const ordered = Object.fromEntries(Object.entries(files).sort(([left], [right]) => left < right ? -1 : left > right ? 1 : 0))
  const hash = createHash("sha256")
  for (const [name, value] of Object.entries(ordered)) hash.update(`${name}\0${value}\0`)
  return { sha256: hash.digest("hex"), files: ordered }
}

export function nativeInputs(root) {
  return fingerprint(root, ["rust", ".cargo"], () => true, ["rust/target"])
}

export function runtimeInputs(root) {
  return fingerprint(root, ["init.lua", "lua", "lazy-lock.json"], (name) => name.endsWith(".lua") || name === "lazy-lock.json")
}

export function pluginInputs(root) {
  return fingerprint(root, ["."], (name) => /\.(?:lua|vim|so|dylib|dll|scm|json|snippets|js|mjs|cjs|wasm)$/.test(name), [".github"])
}

export function writeBuildReceipt(path, source, build) {
  const receipt = {
    schema_version: 1,
    built_at: new Date().toISOString(),
    artifact_sha256: fileHash(path),
    source,
    build,
  }
  writeFileSync(`${path}.build.json`, `${JSON.stringify(receipt, null, 2)}\n`)
  return receipt
}

export function inspectArtifact(root, path) {
  const source = nativeInputs(root)
  const artifactSha256 = fileHash(path)
  const receiptPath = `${path}.build.json`
  if (!existsSync(receiptPath)) {
    return { status: "unverified", reason: "missing build receipt", artifact_sha256: artifactSha256, source }
  }
  let receipt
  try {
    receipt = JSON.parse(readFileSync(receiptPath, "utf8"))
  } catch {
    return { status: "unverified", reason: "invalid build receipt", artifact_sha256: artifactSha256, source }
  }
  const matches = receipt.schema_version === 1
    && receipt.artifact_sha256 === artifactSha256
    && receipt.source?.sha256 === source.sha256
  return {
    status: matches ? "verified" : "mismatch",
    ...(matches ? {} : { reason: "artifact or source differs from build receipt" }),
    artifact_sha256: artifactSha256,
    source,
    receipt,
  }
}
