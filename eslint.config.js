import { genConfigs } from '@guanghechen/eslint-config'
import reactHooks from 'eslint-plugin-react-hooks'
import path from 'node:path'
import url from 'node:url'

const WORKSPACE_DIR = path.dirname(url.fileURLToPath(import.meta.url))

const configs = [
  {
    ignores: ['.vscode/', '**/__tmp__/', '**/doc/', '**/example/', '.prettierrc'],
  },
  ...genConfigs({ tsconfigPath: path.join(WORKSPACE_DIR, './tsconfig.eslint.json') }),
  reactHooks.configs['recommended-latest'],
  {
    files: ['src/**/*.{ts,cts,mts}'],
    rules: {
      '@stylistic/eol-last': ['error', 'always'],
      '@typescript-eslint/no-unused-vars': 'off',
      'no-plusplus': 'off',
      'no-unused-vars': 'off',
    },
  },
  {
    files: ['src/**/*.{tsx,jsx}'],
    rules: {
      'react/jsx-curly-spacing': 'off',
    },
  },
]

export default configs
