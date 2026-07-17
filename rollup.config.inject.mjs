import { nodeResolve } from '@rollup/plugin-node-resolve'
import replace from '@rollup/plugin-replace'
import terser from '@rollup/plugin-terser'
import typescript from '@rollup/plugin-typescript'
import fs from 'node:fs'
import path from 'node:path'
import { SOURCE_INJECT_DIR, TARGET_DIR, YOZ_SERVER_PORT, isProduction } from './script/env.mjs'

const entries = fs
  .readdirSync(SOURCE_INJECT_DIR, { withFileTypes: true })
  .filter(entry => {
    if (!entry.isDirectory()) return false
    return fs.existsSync(path.join(SOURCE_INJECT_DIR, entry.name, 'index.ts'))
  })
  .map(entry => entry.name)
  .sort()

if (entries.length === 0) {
  throw new Error(`No inject entries found in ${SOURCE_INJECT_DIR}`)
}

function createPlugins() {
  return [
    nodeResolve({
      browser: true,
      preferBuiltins: false,
      extensions: ['.ts', '.tsx', '.mjs', '.js', '.jsx', '.json'],
    }),
    typescript({
      tsconfig: 'tsconfig.inject.json',
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
      __YOZ_SERVER_PORT__: JSON.stringify(YOZ_SERVER_PORT),
    }),
    isProduction &&
      terser({
        toplevel: false,
        ecma: '2018',
      }),
  ].filter(Boolean)
}

export default entries.map(entry => ({
  input: path.join(SOURCE_INJECT_DIR, entry, 'index.ts'),
  output: {
    file: path.join(TARGET_DIR, 'inject', `${entry}.js`),
    format: 'esm',
    exports: 'named',
    sourcemap: false,
  },
  external: () => false,
  plugins: createPlugins(),
}))
