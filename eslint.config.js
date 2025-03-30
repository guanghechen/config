import { genConfigs } from '@guanghechen/eslint-config'
import reactHooks from 'eslint-plugin-react-hooks'

const configs = [
  {
    ignores: ['.vscode/', '**/__tmp__/', '**/doc/', '**/example/', '.prettierrc'],
  },
  ...genConfigs({ tsconfigPath: './tsconfig.eslint.json' }),
  reactHooks.configs['recommended-latest'],
  {
    files: ['src/**/*.{ts,cts,mts}'],
    rules: {
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
