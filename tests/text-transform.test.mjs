import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { test } from 'node:test'
import { runInNewContext } from 'node:vm'
import ts from 'typescript'
import { validateTransformConfig } from '../shared/util/transform.ts'

// Compile the actual modules in memory to resolve the application's @/shared alias.
function loadModule(relativePath, imports = {}) {
  const url = new URL(relativePath, import.meta.url)
  const source = ts.transpileModule(readFileSync(url, 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  }).outputText
  const module = { exports: {} }
  runInNewContext(`(function(module, exports, require) { ${source}\n })`)(
    module,
    module.exports,
    specifier => {
      assert(Object.hasOwn(imports, specifier), `Unexpected import: ${specifier}`)
      return imports[specifier]
    },
  )
  return module.exports
}

const types = loadModule('../shared/types/transform.ts')
const { transformTextToNodes } = loadModule('../src/view/filetype/text/util/transform.ts', {
  '@/shared/types': types,
})
const config = {
  name: 'regression',
  desc: 'item => item',
  split: "text => text.split('\\n')",
  steps: [],
  uuid: '(item, index) => String(index)',
  parents: '(item, index) => index > 0 ? [String(index - 1)] : []',
  title: 'item => item',
  chainPaths: ['message', '!details'],
}

function assertRecords(actualConfig) {
  assert.equal(validateTransformConfig(actualConfig), true)
  const result = transformTextToNodes('first\nsecond', actualConfig)
  assert.equal(result.error, undefined)
  assert.deepEqual(
    Array.from(result.nodes, node => node.title),
    ['first', 'second'],
  )
  assert.deepEqual(
    Array.from(result.nodes, node => node.parents.join(',')),
    ['', '0'],
  )
  assert(result.nodes.every(node => !Object.hasOwn(node, 'parents_virtual')))
  assert.deepEqual(actualConfig.chainPaths, ['message', '!details'])
}

test('text transforms accept configs without virtual parents and preserve real parents', () => {
  assertRecords(config)
})

test('legacy virtual-parent callbacks are never executed', () => {
  assertRecords({
    ...config,
    parents_virtual: "() => { throw new Error('obsolete graph callback') }",
  })
})

test('malformed legacy virtual-parent fields are ignored', () => {
  for (const parents_virtual of ['invalid syntax !', null, 42]) {
    assertRecords({ ...config, parents_virtual })
  }
})

test('active parent configuration is still validated and executed', () => {
  const missingParents = { ...config }
  delete missingParents.parents
  assert.equal(validateTransformConfig(missingParents), false)
  const result = transformTextToNodes('first', {
    ...config,
    parents: "() => { throw new Error('active parent callback') }",
  })
  assert.match(result.error, /active parent callback/)
  assert.equal(result.nodes.length, 0)
})
