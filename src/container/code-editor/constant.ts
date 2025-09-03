import { SiteTheme } from '@/context/site'

export const FILETYPE_TO_LANGUAGE_MAP: Record<string, string> = {
  javascript: 'javascript',
  js: 'javascript',
  typescript: 'typescript',
  ts: 'typescript',
  json: 'json',
  html: 'html',
  css: 'css',
  markdown: 'markdown',
  md: 'markdown',
  xml: 'xml',
  svg: 'xml',
  python: 'python',
  py: 'python',
  java: 'java',
  cpp: 'cpp',
  'c++': 'cpp',
  c: 'c',
  sql: 'sql',
  yaml: 'yaml',
  yml: 'yaml',
  text: 'plaintext',
  txt: 'plaintext',
}

export const SITE_THEME_TO_MONACO_THEME_MAP: Record<SiteTheme, string> = {
  [SiteTheme.DARKEN]: 'vs-dark',
  [SiteTheme.LIGHTEN]: 'vs-light',
}

export const SITE_THEME_TO_CUSTOMIZED_THEME_MAP: Record<SiteTheme, string> = {
  [SiteTheme.DARKEN]: 'transparent-dark',
  [SiteTheme.LIGHTEN]: 'transparent-light',
}

export const LANGUAGE_OPTIONS = [
  { value: 'javascript', label: 'JavaScript' },
  { value: 'typescript', label: 'TypeScript' },
  { value: 'python', label: 'Python' },
  { value: 'java', label: 'Java' },
  { value: 'cpp', label: 'C++' },
  { value: 'c', label: 'C' },
  { value: 'html', label: 'HTML' },
  { value: 'css', label: 'CSS' },
  { value: 'json', label: 'JSON' },
  { value: 'xml', label: 'XML' },
  { value: 'sql', label: 'SQL' },
  { value: 'yaml', label: 'YAML' },
  { value: 'markdown', label: 'Markdown' },
  { value: 'plaintext', label: 'Plain Text' },
]

export const DEFAULT_CODE_TEMPLATE_OPTIONS = [
  { value: 'text', label: 'Text' },
  { value: 'markdown', label: 'Markdown' },
  { value: 'json', label: 'JSON' },
  { value: 'html', label: 'HTML' },
  { value: 'svg', label: 'SVG' },
  { value: 'excalidraw', label: 'Excalidraw' },
]
