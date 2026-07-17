import { genConfigs } from '@guanghechen/eslint-config'
import reactHooks from 'eslint-plugin-react-hooks'

const configs = [
  {
    ignores: ['.vscode/', '**/__tmp__/', '**/doc/', '**/example/', '.prettierrc'],
  },
  ...genConfigs({ tsconfigPath: './tsconfig.eslint.json' }),
  reactHooks.configs.flat['recommended-latest'],
  {
    settings: {
      react: { version: 'detect' },
    },
  },
  {
    files: ['**/*.{ts,cts,mts,tsx,ctsx,mtsx}'],
    rules: {
      '@stylistic/arrow-spacing': ['error', { after: true, before: true }],
      '@stylistic/type-annotation-spacing': [
        'error',
        { after: true, before: false, overrides: { arrow: 'ignore' } },
      ],
      '@typescript-eslint/no-unused-vars': 'off',
      'no-plusplus': 'off',
      'no-unused-vars': 'off',
    },
  },
  {
    files: ['**/*.d.ts'],
    rules: {
      'spaced-comment': 'off',
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
