import assert from 'node:assert/strict'
import { existsSync, readdirSync, readFileSync } from 'node:fs'
import path from 'node:path'
import test from 'node:test'

const SOURCE_ROOT = path.resolve('src')
const ALLOWED_LAYER_DEPENDENCIES: Readonly<Record<string, ReadonlySet<string>>> = Object.freeze({
  app: new Set(['app', 'comparison', 'git', 'history', 'platform', 'view']),
  comparison: new Set(['comparison', 'git']),
  extension: new Set(['app', 'comparison', 'git', 'history', 'platform', 'view']),
  git: new Set(['git']),
  history: new Set(['git', 'history']),
  platform: new Set(['platform']),
  view: new Set(['comparison', 'git', 'history', 'platform', 'view']),
})

const sourceFiles = collectTypeScriptFiles(SOURCE_ROOT)
const dependencyGraph = new Map(
  sourceFiles.map(filePath => [filePath, collectInternalDependencies(filePath)]),
)

test('keeps source dependencies within one-way layer boundaries', () => {
  for (const [sourcePath, dependencies] of dependencyGraph) {
    const sourceLayer = resolveLayer(sourcePath)
    const allowedLayers = ALLOWED_LAYER_DEPENDENCIES[sourceLayer]
    assert.ok(allowedLayers, `Unknown source layer: ${sourceLayer}`)

    for (const dependencyPath of dependencies) {
      const dependencyLayer = resolveLayer(dependencyPath)
      assert.ok(
        allowedLayers.has(dependencyLayer),
        `${relativeSourcePath(sourcePath)} must not depend on ${relativeSourcePath(dependencyPath)}`,
      )
    }
  }
})

test('keeps the internal module graph acyclic', () => {
  const completed = new Set<string>()
  const active = new Set<string>()

  for (const sourcePath of sourceFiles) visit(sourcePath, [], active, completed)
})

function visit(
  sourcePath: string,
  ancestors: ReadonlyArray<string>,
  active: Set<string>,
  completed: Set<string>,
): void {
  if (completed.has(sourcePath)) return
  if (active.has(sourcePath)) {
    const cycleStart = ancestors.indexOf(sourcePath)
    const cycle = [...ancestors.slice(cycleStart), sourcePath].map(relativeSourcePath)
    assert.fail(`Circular dependency: ${cycle.join(' -> ')}`)
  }

  active.add(sourcePath)
  for (const dependencyPath of dependencyGraph.get(sourcePath) ?? []) {
    visit(dependencyPath, [...ancestors, sourcePath], active, completed)
  }
  active.delete(sourcePath)
  completed.add(sourcePath)
}

function collectTypeScriptFiles(directoryPath: string): ReadonlyArray<string> {
  const files: string[] = []
  for (const entry of readdirSync(directoryPath, { withFileTypes: true })) {
    const entryPath = path.join(directoryPath, entry.name)
    if (entry.isDirectory()) files.push(...collectTypeScriptFiles(entryPath))
    else if (entry.isFile() && entry.name.endsWith('.ts')) files.push(entryPath)
  }
  return files.sort()
}

function collectInternalDependencies(sourcePath: string): ReadonlyArray<string> {
  const source = readFileSync(sourcePath, 'utf8')
  const dependencies: string[] = []
  for (const match of source.matchAll(/\bfrom\s+['"](\.[^'"]+)['"]/g)) {
    const specifier = match[1]
    if (!specifier) continue
    const dependencyPath = resolveTypeScriptModule(
      path.resolve(path.dirname(sourcePath), specifier),
    )
    assert.ok(dependencyPath, `Cannot resolve ${specifier} from ${relativeSourcePath(sourcePath)}`)
    dependencies.push(dependencyPath)
  }
  return dependencies
}

function resolveTypeScriptModule(modulePath: string): string | null {
  for (const candidate of [`${modulePath}.ts`, path.join(modulePath, 'index.ts')]) {
    if (existsSync(candidate)) return candidate
  }
  return null
}

function resolveLayer(sourcePath: string): string {
  const [firstSegment] = relativeSourcePath(sourcePath).split('/')
  return firstSegment === 'extension.ts' ? 'extension' : (firstSegment ?? '')
}

function relativeSourcePath(sourcePath: string): string {
  return path.relative(SOURCE_ROOT, sourcePath).split(path.sep).join('/')
}
