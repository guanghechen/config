import { useEffect, useRef, useState } from 'react'
import {
  DEFAULT_APPEARANCE_SETTINGS,
  readAppearanceSettings,
  type AppearanceMode,
  type IAppearanceSettings,
  writeAppearanceSettings,
} from '@/shared/setting/appearance'
import { writePageEnabled } from '@/shared/setting/page-enabled'
import type { IThemeOption, ThemeId, ThemeKind } from '@/shared/theme/contract'
import { getThemeOptions, isThemeIdForKind } from '@/shared/theme/registry'
import { readActivePageStatus, type IActivePageStatus } from './active-page'

interface IModeOption {
  readonly value: AppearanceMode
  readonly label: string
}

type SavingTarget = 'appearance' | 'page' | null

const MODE_OPTIONS: ReadonlyArray<IModeOption> = [
  { value: 'system', label: 'System' },
  { value: 'light', label: 'Light' },
  { value: 'dark', label: 'Dark' },
]

const LIGHT_THEME_OPTIONS = getThemeOptions('light')
const DARK_THEME_OPTIONS = getThemeOptions('dark')

export function App() {
  const [appearanceSettings, setAppearanceSettings] = useState<IAppearanceSettings>(
    DEFAULT_APPEARANCE_SETTINGS,
  )
  const [pageStatus, setPageStatus] = useState<IActivePageStatus | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [savingTarget, setSavingTarget] = useState<SavingTarget>(null)
  const savingTargetRef = useRef<SavingTarget>(null)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  useEffect(() => {
    let active = true

    void Promise.allSettled([readAppearanceSettings(), readActivePageStatus()]).then(
      ([appearanceResult, pageResult]) => {
        if (!active) return

        const errors: string[] = []
        if (appearanceResult.status === 'fulfilled') setAppearanceSettings(appearanceResult.value)
        else errors.push('Could not load the appearance settings.')

        if (pageResult.status === 'fulfilled') setPageStatus(pageResult.value)
        else errors.push('Could not check the current page.')

        setErrorMessage(errors.length > 0 ? errors.join(' ') : null)
        setIsLoading(false)
      },
    )

    return () => {
      active = false
    }
  }, [])

  useEffect(() => {
    document.documentElement.dataset.theme = appearanceSettings.mode
  }, [appearanceSettings.mode])

  async function updatePageEnabled(enabled: boolean): Promise<void> {
    if (!pageStatus || savingTargetRef.current !== null || enabled === pageStatus.enabled) return

    const previousStatus = pageStatus
    savingTargetRef.current = 'page'
    setPageStatus({ ...pageStatus, enabled })
    setSavingTarget('page')
    setErrorMessage(null)

    try {
      await writePageEnabled(pageStatus.url, enabled)
    } catch {
      setPageStatus(previousStatus)
      setErrorMessage('Could not update this site. The previous setting was restored.')
    } finally {
      savingTargetRef.current = null
      setSavingTarget(null)
    }
  }

  async function updateAppearanceSettings(nextValue: IAppearanceSettings): Promise<void> {
    if (savingTargetRef.current !== null || isSameAppearanceSettings(nextValue, appearanceSettings))
      return

    const previousValue = appearanceSettings
    savingTargetRef.current = 'appearance'
    setAppearanceSettings(nextValue)
    setSavingTarget('appearance')
    setErrorMessage(null)

    try {
      await writeAppearanceSettings(nextValue)
    } catch {
      setAppearanceSettings(previousValue)
      setErrorMessage('Could not save the appearance. The previous settings were restored.')
    } finally {
      savingTargetRef.current = null
      setSavingTarget(null)
    }
  }

  function updateMode(mode: AppearanceMode): void {
    void updateAppearanceSettings({ ...appearanceSettings, mode })
  }

  function updateTheme(kind: ThemeKind, value: string): void {
    if (!isThemeIdForKind(value, kind)) return

    const nextValue: IAppearanceSettings =
      kind === 'light'
        ? { ...appearanceSettings, lightTheme: value }
        : { ...appearanceSettings, darkTheme: value }
    void updateAppearanceSettings(nextValue)
  }

  const isBusy = isLoading || savingTarget !== null
  const pageControlDisabled = isBusy || !pageStatus
  const appearanceControlDisabled = isBusy || pageStatus?.enabled === false
  const statusMessage =
    errorMessage ??
    (isLoading
      ? 'Checking this page…'
      : savingTarget === 'page'
        ? 'Updating this site…'
        : savingTarget === 'appearance'
          ? 'Saving appearance…'
          : '')

  return (
    <main className="popup-shell" aria-busy={isBusy}>
      <header className="app-header">
        <img className="brand-logo" src="/images/icon-48.png" alt="" />
        <div className="app-heading">
          <h1>Tsuki</h1>
          <p>Theme and reading</p>
        </div>
      </header>

      <section className="settings-panel" aria-label="Appearance settings">
        <div className="setting-row">
          <div className="setting-copy">
            <h2>Use Tsuki on this site</h2>
            <p>
              {isLoading ? 'Checking current page…' : (pageStatus?.label ?? 'Not available here')}
            </p>
          </div>

          <label className="switch-control">
            <span className="visually-hidden">Use Tsuki on this site</span>
            <input
              type="checkbox"
              role="switch"
              checked={pageStatus?.enabled ?? false}
              disabled={pageControlDisabled}
              onChange={event => void updatePageEnabled(event.target.checked)}
            />
            <span className="switch-track" aria-hidden="true" />
          </label>
        </div>

        <div className="settings-divider" />

        <fieldset
          className="appearance-setting"
          aria-describedby="appearance-description appearance-status"
          disabled={appearanceControlDisabled}
        >
          <legend>Appearance</legend>
          <p id="appearance-description">Choose the mode and color themes.</p>

          <div className="mode-control">
            <span className="control-label">Mode</span>
            <div className="theme-options">
              {MODE_OPTIONS.map(option => (
                <label className="theme-option" key={option.value}>
                  <input
                    type="radio"
                    name="appearance-mode"
                    value={option.value}
                    checked={appearanceSettings.mode === option.value}
                    onChange={() => updateMode(option.value)}
                  />
                  <span>{option.label}</span>
                </label>
              ))}
            </div>
          </div>

          <div className="theme-selectors">
            <ThemeSelect
              kind="light"
              label="Light theme"
              value={appearanceSettings.lightTheme}
              options={LIGHT_THEME_OPTIONS}
              onChange={value => updateTheme('light', value)}
            />
            <ThemeSelect
              kind="dark"
              label="Dark theme"
              value={appearanceSettings.darkTheme}
              options={DARK_THEME_OPTIONS}
              onChange={value => updateTheme('dark', value)}
            />
          </div>
        </fieldset>
      </section>

      <p
        id="appearance-status"
        className={errorMessage ? 'status-message status-message-error' : 'status-message'}
        role={errorMessage ? 'alert' : 'status'}
        aria-live="polite"
      >
        {statusMessage}
      </p>
    </main>
  )
}

interface IThemeSelectProps {
  readonly kind: ThemeKind
  readonly label: string
  readonly value: ThemeId
  readonly options: ReadonlyArray<IThemeOption>
  readonly onChange: (value: string) => void
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

function isSameAppearanceSettings(left: IAppearanceSettings, right: IAppearanceSettings): boolean {
  return (
    left.mode === right.mode &&
    left.lightTheme === right.lightTheme &&
    left.darkTheme === right.darkTheme
  )
}
