import type { IThemeDefinition, IThemeOption, ThemeId, ThemeKind } from './contract'
import { COLOR_THEME_IDS } from './contract'
import { vscodeDarkModernTheme } from './vscode-dark-modern'
import { vscodeLightModernTheme } from './vscode-light-modern'

const ORIGINAL_THEME_OPTION: IThemeOption = {
  id: 'original',
  label: 'Original',
}

export const THEME_DEFINITIONS: ReadonlyArray<IThemeDefinition> = [
  vscodeLightModernTheme,
  vscodeDarkModernTheme,
]

const THEME_DEFINITION_MAP = new Map(
  THEME_DEFINITIONS.map(definition => [definition.id, definition] as const),
)

export function getThemeDefinition(id: ThemeId): IThemeDefinition | null {
  if (id === 'original') return null
  return THEME_DEFINITION_MAP.get(id) ?? null
}

export function getThemeOptions(kind: ThemeKind): ReadonlyArray<IThemeOption> {
  return [
    ORIGINAL_THEME_OPTION,
    ...THEME_DEFINITIONS.filter(definition => definition.kind === kind).map(definition => ({
      id: definition.id,
      label: definition.label,
    })),
  ]
}

export function isThemeId(value: unknown): value is ThemeId {
  return value === 'original' || COLOR_THEME_IDS.includes(value as (typeof COLOR_THEME_IDS)[number])
}

export function isThemeIdForKind(value: unknown, kind: ThemeKind): value is ThemeId {
  if (value === 'original') return true
  if (!isThemeId(value)) return false
  return getThemeDefinition(value)?.kind === kind
}
