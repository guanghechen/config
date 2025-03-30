import { createRollupConfig, tsPresetConfigBuilder } from '@guanghechen/rollup-config'
import replace from '@rollup/plugin-replace'
import terser from '@rollup/plugin-terser'
import fs from 'node:fs'
import path from 'node:path'
import { SOURCE_INJECT_DIR, TARGET_DIR, extensionManifest, isProduction } from './script/env.mjs'

export default async function rollupConfig() {
  const entries = fs
    .readdirSync(SOURCE_INJECT_DIR)
    .filter(p => fs.existsSync(path.join(SOURCE_INJECT_DIR, p, 'index.ts')))

  const manifest = { exports: {} }
  for (const entry of entries) {
    const source = path.join(SOURCE_INJECT_DIR, entry, 'index.ts')
    const target = path.join(TARGET_DIR, 'inject', entry + '.js')
    manifest.exports[entry] = {
      source,
      import: target,
    }
  }

  const tsBuilder = tsPresetConfigBuilder({
    typescriptOptions: {
      tsconfig: 'tsconfig.inject.json',
      compilerOptions: {
        outDir: TARGET_DIR,
        declarationDir: TARGET_DIR,
      },
    },
  })

  const config = await createRollupConfig({
    manifest,
    env: { sourcemap: false },
    presetConfigBuilders: [
      {
        name: tsBuilder.name,
        build: async ctx => {
          const config = tsBuilder.build(ctx)
          return {
            ...config,
            plugins: [
              ...config.plugins,
              replace({
                preventAssignment: true,
                'process.env.NODE_ENV': JSON.stringify(process.env.NODE_ENV),
                'process.env.EXTENSION_VERSION': JSON.stringify(extensionManifest.version),
                'process.env.SBSExtensionVersion': JSON.stringify(extensionManifest.version),
                'process.env.SBSExtensionVersionMinimal': JSON.stringify(
                  extensionManifest.version_minimal,
                ),
              }),
              isProduction &&
                terser({
                  toplevel: false,
                  ecma: '2018',
                }),
            ].filter(Boolean),
            external: () => false,
          }
        },
      },
    ],
  })
  return config
}
