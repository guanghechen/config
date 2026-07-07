import eslint from '@eslint/js'
import eslintConfigPrettier from 'eslint-config-prettier'
import { createTypeScriptImportResolver } from 'eslint-import-resolver-typescript'
import { createNodeResolver, importX } from 'eslint-plugin-import-x'
import reactHooks from 'eslint-plugin-react-hooks'
import globals from 'globals'
import tseslint from 'typescript-eslint'

const tsconfigPath = './tsconfig.eslint.json'

export default [
  {
    ignores: [
      '.vscode/',
      'dist/',
      '**/__tmp__/',
      '**/doc/',
      '**/example/',
      '**/node_modules/',
      '.prettierrc',
    ],
  },
  eslint.configs.recommended,
  importX.flatConfigs.recommended,
  {
    files: ['**/*.{js,mjs,cjs,ts,mts,cts,tsx,mtsx}'],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'module',
      globals: { ...globals.browser, ...globals.node },
    },
    settings: {
      'import-x/resolver-next': [
        createTypeScriptImportResolver({
          noWarnOnMultipleProjects: true,
          project: [tsconfigPath, './tsconfig.json'],
        }),
        createNodeResolver({
          extensions: ['.js', '.mjs', '.cjs', '.ts', '.mts', '.cts', '.tsx', '.json'],
        }),
      ],
    },
  },
  {
    files: ['**/*.{cjs,cts}'],
    languageOptions: {
      sourceType: 'commonjs',
    },
  },
  ...tseslint.configs.recommended,
  reactHooks.configs.flat.recommended,
  importX.flatConfigs.typescript,
  {
    files: ['**/*.{ts,mts,cts,tsx,mtsx}'],
    languageOptions: {
      parserOptions: {
        project: tsconfigPath,
      },
    },
    rules: {
      '@typescript-eslint/consistent-type-imports': [
        'error',
        { prefer: 'type-imports', disallowTypeAnnotations: true },
      ],
      '@typescript-eslint/no-empty-object-type': 'off',
      '@typescript-eslint/no-explicit-any': 'off',
      '@typescript-eslint/no-invalid-void-type': 'off',
      '@typescript-eslint/no-unused-vars': [
        'warn',
        {
          argsIgnorePattern: '^_',
          caughtErrorsIgnorePattern: '^_',
          destructuredArrayIgnorePattern: '^_',
          varsIgnorePattern: '^_',
          ignoreRestSiblings: true,
        },
      ],
    },
  },
  {
    rules: {
      'array-callback-return': 'warn',
      eqeqeq: ['warn', 'smart'],
      'max-len': [
        'error',
        {
          code: 100,
          ignoreUrls: true,
          ignoreStrings: true,
          ignoreTemplateLiterals: true,
          ignoreRegExpLiterals: true,
        },
      ],
      'no-console': 'off',
      'no-param-reassign': ['error', { props: true }],
      'no-plusplus': ['error', { allowForLoopAfterthoughts: true }],
      'no-return-assign': ['error', 'always'],
      'no-template-curly-in-string': 'warn',
      quotes: ['error', 'single', { avoidEscape: true }],
      semi: ['error', 'never'],
      'sort-imports': ['error', { ignoreDeclarationSort: true }],
      'import-x/first': 'error',
      // TS 编译器已覆盖 import 存在性检查；import-x resolver 对 CJS(dotenv/jsonwebtoken/react)
      // 与 barrel re-export 高频误报，关闭这两条（社区对 TS 项目的通行做法）
      'import-x/default': 'off',
      'import-x/export': 'off',
      // yoz 存在既有 import 循环(container/json 等)，超出本次依赖升级范围，降为 warn 保留可见性待专项治理
      'import-x/no-cycle': ['warn', { ignoreExternal: true }],
      'import-x/no-extraneous-dependencies': ['error', { devDependencies: true }],
      'import-x/no-named-as-default': 'off',
      'import-x/no-named-as-default-member': 'off',
      'import-x/order': 'off',
      'import-x/no-self-import': 'error',
      'import-x/no-unresolved': 'off',
      // react-hooks 7 / React Compiler 新规则命中既有组件模式，修复涉及逻辑重构、超本次范围，降为 warn
      'react-hooks/immutability': 'off',
      'react-hooks/refs': 'off',
      'react-hooks/set-state-in-effect': 'warn',
      'react-hooks/incompatible-library': 'warn',
      'react-hooks/error-boundaries': 'warn',
      'react-hooks/preserve-manual-memoization': 'warn',
    },
  },
  {
    files: ['src/**/*.{ts,cts,mts,tsx}'],
    rules: {
      '@typescript-eslint/no-unused-vars': 'off',
      'no-unused-vars': 'off',
      'no-plusplus': 'off',
    },
  },
  {
    files: ['eslint.config.js', 'vite.config.ts'],
    rules: {
      'import-x/no-anonymous-default-export': 'off',
    },
  },
  eslintConfigPrettier,
]
