import assert from 'node:assert/strict'
import { readFileSync, readdirSync } from 'node:fs'
import path from 'node:path'
import { test } from 'node:test'
import ts from 'typescript'

const root = path.resolve(import.meta.dirname, '../src/view/whiteboard')
const files = readdirSync(root, { recursive: true }).filter(name => /\.(tsx?|css)$/.test(name))
const all = new Set(files.map(name => path.join(root, name)))
const imports = new Map()
for (const name of files.filter(name => /\.tsx?$/.test(name))) {
  const filename = path.join(root, name)
  const source = ts.createSourceFile(
    filename,
    readFileSync(filename, 'utf8'),
    ts.ScriptTarget.Latest,
    true,
  )
  const paths = []
  const visit = node => {
    if (
      (ts.isImportDeclaration(node) || ts.isExportDeclaration(node)) &&
      node.moduleSpecifier &&
      ts.isStringLiteral(node.moduleSpecifier)
    )
      paths.push(node.moduleSpecifier.text)
    if (
      ts.isCallExpression(node) &&
      node.expression.kind === ts.SyntaxKind.ImportKeyword &&
      ts.isStringLiteral(node.arguments[0])
    )
      paths.push(node.arguments[0].text)
    ts.forEachChild(node, visit)
  }
  visit(source)
  imports.set(filename, paths)
}
const resolve = (filename, specifier) => {
  const target = specifier.startsWith('.')
    ? path.resolve(path.dirname(filename), specifier)
    : specifier.startsWith('@/view/whiteboard/')
      ? path.join(root, specifier.slice('@/view/whiteboard/'.length))
      : null
  return target && [target, `${target}.ts`, `${target}.tsx`].find(value => all.has(value))
}
const isHost = filename =>
  filename.startsWith(path.join(root, 'host/')) || filename === path.join(root, 'View.tsx')

test('editor code reaches project services only through its host boundary', () => {
  const common = new Set(['@/common/component/virtual-list/VirtualList'])
  for (const [filename, specifiers] of imports) {
    if (isHost(filename)) continue
    for (const specifier of specifiers) {
      const target = resolve(filename, specifier)
      assert.ok(!target || !isHost(target), `${filename} imports host implementation ${specifier}`)
      if (specifier.startsWith('@/'))
        assert.ok(
          specifier.startsWith('@/shared/whiteboard/') || common.has(specifier),
          `${filename} imports project service ${specifier}`,
        )
    }
    const source = readFileSync(filename, 'utf8')
    assert.doesNotMatch(
      source,
      /import\.meta\.hot|window\.location|localStorage|\/api\//,
      `${filename} contains an implicit host dependency`,
    )
  }
})

test('standalone entry has no router, site provider, Monaco or host dependency', () => {
  const visited = new Set()
  const visit = filename => {
    if (visited.has(filename)) return
    visited.add(filename)
    assert.ok(!isHost(filename), `Standalone entry reaches ${filename}`)
    for (const specifier of imports.get(filename) ?? []) {
      const target = resolve(filename, specifier)
      if (target) visit(target)
      else if (!specifier.startsWith('.') && !specifier.startsWith('@/'))
        assert.ok(
          ['react', 'react-dom'].includes(specifier),
          `Standalone entry reaches ${specifier}`,
        )
    }
  }
  visit(path.join(root, 'Whiteboard.tsx'))
  assert.ok(visited.size > 20, 'The check must traverse the actual editor, not a stub entry')
})

test('whiteboard internal imports stay acyclic, including lazy imports and types', () => {
  const done = new Set(),
    stack = new Set()
  const visit = filename => {
    assert.ok(
      !stack.has(filename),
      `Dependency cycle: ${[...stack, filename].map(p => path.relative(root, p)).join(' -> ')}`,
    )
    if (done.has(filename)) return
    stack.add(filename)
    for (const specifier of imports.get(filename) ?? []) {
      const target = resolve(filename, specifier)
      if (target) visit(target)
    }
    stack.delete(filename)
    done.add(filename)
  }
  for (const filename of imports.keys()) visit(filename)
})

test('editor styles use local tokens and do not require site or layout selectors', () => {
  for (const name of files.filter(name => name.endsWith('.css') && !name.startsWith('host/'))) {
    const source = readFileSync(path.join(root, name), 'utf8')
    assert.doesNotMatch(source, /--vscode-|--palette-|\.vl-main|\.yozora/, name)
  }
})
