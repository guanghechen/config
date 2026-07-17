import { useEffect, useState } from 'react'
import { writePageEnabled } from '@/shared/setting/page-enabled'
import {
  DEFAULT_THEME_PREFERENCE,
  readThemePreference,
  type ThemePreference,
  writeThemePreference,
} from '@/shared/setting/theme-preference'
import { readActivePageStatus, type IActivePageStatus } from './active-page'

interface IThemeOption {
  readonly value: ThemePreference
  readonly label: string
}

type SavingTarget = 'page' | 'theme' | null

const THEME_OPTIONS: ReadonlyArray<IThemeOption> = [
  { value: 'system', label: 'System' },
  { value: 'light', label: 'Light' },
  { value: 'dark', label: 'Dark' },
]

export function App() {
  const [themePreference, setThemePreference] = useState<ThemePreference>(DEFAULT_THEME_PREFERENCE)
  const [pageStatus, setPageStatus] = useState<IActivePageStatus | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [savingTarget, setSavingTarget] = useState<SavingTarget>(null)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  useEffect(() => {
    let active = true

    void Promise.allSettled([readThemePreference(), readActivePageStatus()]).then(
      ([themeResult, pageResult]) => {
        if (!active) return

        const errors: string[] = []
        if (themeResult.status === 'fulfilled') setThemePreference(themeResult.value)
        else errors.push('Could not load the saved theme.')

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
    document.documentElement.dataset.theme = themePreference
  }, [themePreference])

  async function updatePageEnabled(enabled: boolean): Promise<void> {
    if (!pageStatus || savingTarget !== null || enabled === pageStatus.enabled) return

    const previousStatus = pageStatus
    setPageStatus({ ...pageStatus, enabled })
    setSavingTarget('page')
    setErrorMessage(null)

    try {
      await writePageEnabled(pageStatus.url, enabled)
    } catch {
      setPageStatus(previousStatus)
      setErrorMessage('Could not update this site. The previous setting was restored.')
    } finally {
      setSavingTarget(null)
    }
  }

  async function updateThemePreference(nextValue: ThemePreference): Promise<void> {
    if (savingTarget !== null || nextValue === themePreference) return

    const previousValue = themePreference
    setThemePreference(nextValue)
    setSavingTarget('theme')
    setErrorMessage(null)

    try {
      await writeThemePreference(nextValue)
    } catch {
      setThemePreference(previousValue)
      setErrorMessage('Could not save the theme. The previous setting was restored.')
    } finally {
      setSavingTarget(null)
    }
  }

  const isBusy = isLoading || savingTarget !== null
  const pageControlDisabled = isBusy || !pageStatus
  const themeControlDisabled = isBusy || pageStatus?.enabled === false
  const statusMessage =
    errorMessage ??
    (isLoading
      ? 'Checking this page…'
      : savingTarget === 'page'
        ? 'Updating this site…'
        : savingTarget === 'theme'
          ? 'Saving theme…'
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
          className="theme-setting"
          aria-describedby="theme-description theme-status"
          disabled={themeControlDisabled}
        >
          <legend>Theme</legend>
          <p id="theme-description">Choose the appearance for supported pages.</p>

          <div className="theme-options">
            {THEME_OPTIONS.map(option => (
              <label className="theme-option" key={option.value}>
                <input
                  type="radio"
                  name="theme-preference"
                  value={option.value}
                  checked={themePreference === option.value}
                  onChange={() => void updateThemePreference(option.value)}
                />
                <span>{option.label}</span>
              </label>
            ))}
          </div>
        </fieldset>
      </section>

      <p
        id="theme-status"
        className={errorMessage ? 'status-message status-message-error' : 'status-message'}
        role={errorMessage ? 'alert' : 'status'}
        aria-live="polite"
      >
        {statusMessage}
      </p>
    </main>
  )
}
