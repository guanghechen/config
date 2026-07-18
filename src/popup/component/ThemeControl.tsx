import type { IAppearanceSettings } from '@/shared/setting/appearance'
import type { IThemeOption, ThemeId, ThemeKind } from '@/shared/theme/contract'
import { getThemeOptions } from '@/shared/theme/registry'

interface IThemeControlProps {
  readonly settings: IAppearanceSettings
  readonly onChange: (kind: ThemeKind, value: string) => void
}

interface IThemeSelectProps {
  readonly kind: ThemeKind
  readonly label: string
  readonly value: ThemeId
  readonly options: ReadonlyArray<IThemeOption>
  readonly onChange: (value: string) => void
}

const LIGHT_THEME_OPTIONS = getThemeOptions('light')
const DARK_THEME_OPTIONS = getThemeOptions('dark')

export function ThemeControl({ settings, onChange }: IThemeControlProps) {
  return (
    <div className="theme-selectors">
      <ThemeSelect
        kind="light"
        label="Light theme"
        value={settings.lightTheme}
        options={LIGHT_THEME_OPTIONS}
        onChange={value => onChange('light', value)}
      />
      <ThemeSelect
        kind="dark"
        label="Dark theme"
        value={settings.darkTheme}
        options={DARK_THEME_OPTIONS}
        onChange={value => onChange('dark', value)}
      />
    </div>
  )
}

function ThemeSelect({ kind, label, value, options, onChange }: IThemeSelectProps) {
  return (
    <label className="theme-select-row">
      <span>{label}</span>
      <select
        aria-label={label}
        value={value}
        onChange={event => onChange(event.target.value)}
        data-theme-kind={kind}
      >
        {options.map(option => (
          <option value={option.id} key={option.id}>
            {option.label}
          </option>
        ))}
      </select>
    </label>
  )
}
