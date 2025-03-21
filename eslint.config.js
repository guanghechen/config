import { genConfigs } from '@guanghechen/eslint-config'
import reactHooks from 'eslint-plugin-react-hooks'
import tailwindcss from 'eslint-plugin-tailwindcss'

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
      'tailwindcss/classnames-order': 'warn',
    },
    plugins: {
      tailwindcss,
    },
  },
]

export default configs
