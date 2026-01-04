import type { Options as PrettierOptions } from 'prettier'

export type IPrettierParser = 'babel' | 'typescript' | 'json' | 'css' | 'html' | 'markdown' | 'yaml'

// Lazy-loaded prettier and parsers
let prettierInstance: any = null
const parsersCache: Record<string, any> = {}

export interface IPrettierResult {
  readonly success: boolean
  readonly formatted?: string
  readonly error?: string
}

export interface IPrettierFormatOptions {
  readonly parser: IPrettierParser
  readonly printWidth?: number
  readonly tabWidth?: number
  readonly useTabs?: boolean
  readonly semi?: boolean
  readonly singleQuote?: boolean
  readonly trailingComma?: 'none' | 'es5' | 'all'
}

const LANGUAGE_TO_PARSER_MAP: Record<string, IPrettierParser> = {
  javascript: 'babel',
  js: 'babel',
  jsx: 'babel',
  typescript: 'typescript',
  ts: 'typescript',
  tsx: 'typescript',
  json: 'json',
  jsonl: 'json', // JSONL will be handled line by line using json parser
  css: 'css',
  scss: 'css',
  sass: 'css',
  less: 'css',
  html: 'html',
  htm: 'html',
  xml: 'html',
  svg: 'html',
  markdown: 'markdown',
  md: 'markdown',
  yaml: 'yaml',
  yml: 'yaml',
}

const DEFAULT_OPTIONS: Partial<PrettierOptions> = {
  printWidth: 100,
  tabWidth: 2,
  useTabs: false,
  semi: false,
  singleQuote: true,
  trailingComma: 'es5',
  bracketSpacing: true,
  bracketSameLine: false,
  arrowParens: 'avoid',
}

export const getSupportedLanguages = (): string[] => {
  return Object.keys(LANGUAGE_TO_PARSER_MAP)
}

export const isLanguageSupported = (language: string): boolean => {
  return language in LANGUAGE_TO_PARSER_MAP
}

export const getParserForLanguage = (language: string): IPrettierParser | null => {
  return LANGUAGE_TO_PARSER_MAP[language] || null
}

// Load prettier and required parsers dynamically
const loadPrettierWithParsers = async (parser: IPrettierParser): Promise<any> => {
  if (!prettierInstance) {
    prettierInstance = await import('prettier')
  }

  // For browser environment, try to load all plugins at once
  if (Object.keys(parsersCache).length === 0) {
    try {
      // Try to load the most common parsers
      const [babelPlugin, typescriptPlugin, estreePlugin, postcssPlugin, htmlPlugin] =
        await Promise.allSettled([
          import('prettier/plugins/babel').catch(() => null),
          import('prettier/plugins/typescript').catch(() => null),
          import('prettier/plugins/estree').catch(() => null),
          import('prettier/plugins/postcss').catch(() => null),
          import('prettier/plugins/html').catch(() => null),
        ])

      // Store available parsers
      parsersCache['babel'] = babelPlugin.status === 'fulfilled' ? babelPlugin.value : null
      parsersCache['typescript'] =
        typescriptPlugin.status === 'fulfilled' ? typescriptPlugin.value : null
      parsersCache['json'] = estreePlugin.status === 'fulfilled' ? estreePlugin.value : null
      parsersCache['css'] = postcssPlugin.status === 'fulfilled' ? postcssPlugin.value : null
      parsersCache['html'] = htmlPlugin.status === 'fulfilled' ? htmlPlugin.value : null

      // Try markdown and yaml separately as they might not be available
      try {
        parsersCache['markdown'] = await import('prettier/plugins/markdown')
      } catch {
        parsersCache['markdown'] = null
      }

      try {
        parsersCache['yaml'] = await import('prettier/plugins/yaml')
      } catch {
        parsersCache['yaml'] = null
      }
    } catch (error) {
      console.warn('Failed to load some Prettier parsers:', error)
    }
  }

  // Ensure the required parser is loaded for the specific request
  if (!parsersCache[parser]) {
    try {
      switch (parser) {
        case 'babel':
          parsersCache[parser] = await import('prettier/plugins/babel')
          break
        case 'typescript':
          parsersCache[parser] = await import('prettier/plugins/typescript')
          break
        case 'json':
          parsersCache[parser] = await import('prettier/plugins/estree')
          break
        case 'css':
          parsersCache[parser] = await import('prettier/plugins/postcss')
          break
        case 'html':
          parsersCache[parser] = await import('prettier/plugins/html')
          break
        case 'markdown':
          parsersCache[parser] = await import('prettier/plugins/markdown')
          break
        case 'yaml':
          parsersCache[parser] = await import('prettier/plugins/yaml')
          break
      }
    } catch (error) {
      console.warn(`Failed to load parser ${parser}:`, error)
      parsersCache[parser] = null
    }
  }

  return prettierInstance
}

const formatJsonlLine = async (
  line: string,
  lineNumber: number,
  prettier: any,
  prettierOptions: PrettierOptions,
): Promise<{ success: boolean; formatted?: string; error?: string }> => {
  try {
    // Skip empty lines
    if (!line.trim()) {
      return { success: true, formatted: '' }
    }

    // Try to parse as JSON first to validate
    JSON.parse(line)

    // Format the line as JSON
    const plugins = Object.values(parsersCache).filter(plugin => plugin !== null)
    const formatted = await prettier.format(line, {
      ...prettierOptions,
      ...(plugins.length > 0 ? { plugins } : {}),
    })
    return { success: true, formatted: formatted.trim() }
  } catch (error) {
    return {
      success: false,
      error: `Line ${lineNumber}: ${error instanceof Error ? error.message : 'Invalid JSON'}`,
    }
  }
}

export const formatCode = async (
  code: string,
  language: string,
  options: Partial<IPrettierFormatOptions> = {},
): Promise<IPrettierResult> => {
  try {
    if (!code || !code.trim()) {
      return {
        success: false,
        error: 'No code provided to format',
      }
    }

    const parser = getParserForLanguage(language)
    if (!parser) {
      return {
        success: false,
        error: `Language "${language}" is not supported by Prettier. Supported languages: ${getSupportedLanguages().join(', ')}`,
      }
    }

    // Load prettier and required parsers
    const prettier = await loadPrettierWithParsers(parser)

    // Collect available plugins
    const plugins = Object.values(parsersCache).filter(plugin => plugin !== null)

    const prettierOptions: PrettierOptions = {
      ...DEFAULT_OPTIONS,
      ...options,
      parser,
      ...(plugins.length > 0 ? { plugins } : {}),
    }

    // Special handling for JSONL - format each line separately
    if (language.toLowerCase() === 'jsonl') {
      const lines = code.split('\n')
      const formattedLines: string[] = []
      const errors: string[] = []

      for (let i = 0; i < lines.length; i++) {
        const result = await formatJsonlLine(lines[i], i + 1, prettier, prettierOptions)
        if (result.success) {
          formattedLines.push(result.formatted || '')
        } else {
          errors.push(result.error || `Line ${i + 1}: Unknown error`)
          // Keep the original line if formatting fails
          formattedLines.push(lines[i])
        }
      }

      if (errors.length > 0) {
        return {
          success: false,
          error: `JSONL formatting errors:\n${errors.join('\n')}`,
        }
      }

      const formatted = formattedLines.join('\n')
      return {
        success: true,
        formatted,
      }
    }

    const formatted = await prettier.format(code, prettierOptions)

    if (!formatted || formatted === code) {
      return {
        success: true,
        formatted: code.trim(),
      }
    }

    return {
      success: true,
      formatted: formatted.trim(),
    }
  } catch (error) {
    // Try fallback without plugins if plugins caused the error
    const availablePlugins = Object.values(parsersCache).filter(plugin => plugin !== null)
    const parserForLanguage = getParserForLanguage(language)

    if (
      availablePlugins.length > 0 &&
      parserForLanguage &&
      prettierInstance &&
      error instanceof Error &&
      error.message.includes('parser')
    ) {
      try {
        const fallbackOptions: PrettierOptions = {
          ...DEFAULT_OPTIONS,
          ...options,
          parser: parserForLanguage,
        }
        const fallbackFormatted = await prettierInstance.format(code, fallbackOptions)
        return {
          success: true,
          formatted: fallbackFormatted.trim(),
        }
      } catch (fallbackError) {
        // Continue to original error handling
      }
    }

    let errorMessage = 'Unknown formatting error'

    if (error instanceof Error) {
      errorMessage = error.message

      if (errorMessage.includes('SyntaxError')) {
        errorMessage = `Syntax error in ${language} code: ${errorMessage}`
      } else if (errorMessage.includes('Unexpected token')) {
        errorMessage = `Invalid ${language} syntax: ${errorMessage}`
      } else if (errorMessage.includes('parser')) {
        errorMessage = `Parser error for ${language}: ${errorMessage}`
      }
    }

    return {
      success: false,
      error: `Prettier formatting failed: ${errorMessage}`,
    }
  }
}

export const formatCodeSync = (
  _code: string,
  language: string,
  _options: Partial<IPrettierFormatOptions> = {},
): IPrettierResult => {
  try {
    const parser = getParserForLanguage(language)
    if (!parser) {
      return {
        success: false,
        error: `Language "${language}" is not supported by Prettier`,
      }
    }

    return {
      success: false,
      error: 'Synchronous formatting is not available. Use formatCode() instead.',
    }
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown formatting error'
    return {
      success: false,
      error: `Prettier formatting failed: ${errorMessage}`,
    }
  }
}
