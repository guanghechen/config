import { nodeResolve } from '@rollup/plugin-node-resolve'
import replace from '@rollup/plugin-replace'
import terser from '@rollup/plugin-terser'
import typescript from '@rollup/plugin-typescript'
import fs from 'node:fs'
import path from 'node:path'
import {
  AGENT_BRIDGE_PORT,
  ROOT_DIR,
  SOURCE_INJECT_DIR,
  TARGET_DIR,
  YOZ_SERVER_PORT,
  isProduction,
} from './script/env.mjs'

const BACKGROUND_ENTRY = path.join(ROOT_DIR, 'src/background/index.ts')
const injectEntries = fs
  .readdirSync(SOURCE_INJECT_DIR, { withFileTypes: true })
  .filter(entry => {
    if (!entry.isDirectory()) return false
    return fs.existsSync(path.join(SOURCE_INJECT_DIR, entry.name, 'index.ts'))
  })
  .map(entry => entry.name)
  .sort()

if (injectEntries.length === 0) {
  throw new Error(`No inject entries found in ${SOURCE_INJECT_DIR}`)
}
if (!fs.existsSync(BACKGROUND_ENTRY)) {
  throw new Error(`No background entry found at ${BACKGROUND_ENTRY}`)
}

function createPlugins() {
  return [
    nodeResolve({
      browser: true,
      preferBuiltins: false,
      extensions: ['.ts', '.tsx', '.mjs', '.js', '.jsx', '.json'],
    }),
    typescript({
      tsconfig: 'tsconfig.extension.json',
      compilerOptions: {
        outDir: TARGET_DIR,
        declaration: false,
        declarationMap: false,
        removeComments: true,
        sourceMap: false,
      },
    }),
    replace({
      preventAssignment: true,
      __AGENT_BRIDGE_PORT__: JSON.stringify(AGENT_BRIDGE_PORT),
      __YOZ_SERVER_PORT__: JSON.stringify(YOZ_SERVER_PORT),
    }),
    isProduction &&
      terser({
        toplevel: false,
        ecma: '2018',
      }),
  ].filter(Boolean)
}

function createConfig(input, output) {
  return {
    input,
    output: {
      file: output,
      format: 'esm',
      exports: 'named',
      sourcemap: false,
    },
    external: () => false,
    plugins: createPlugins(),
  }
}

const injectConfigs = injectEntries.map(entry =>
  createConfig(
    path.join(SOURCE_INJECT_DIR, entry, 'index.ts'),
    path.join(TARGET_DIR, 'inject', `${entry}.js`),
  ),
)

export default [
  ...injectConfigs,
  createConfig(BACKGROUND_ENTRY, path.join(TARGET_DIR, 'background.js')),
]
