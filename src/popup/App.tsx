import { useEffect, useState } from 'react'
import {
  DEFAULT_THEME_PREFERENCE,
  readThemePreference,
  type ThemePreference,
  writeThemePreference,
} from '@/shared/setting/theme-preference'

interface IThemeOption {
  readonly value: ThemePreference
  readonly label: string
  readonly description: string
  readonly icon: string
}

const THEME_OPTIONS: ReadonlyArray<IThemeOption> = [
  {
    value: 'system',
    label: 'System',
    description: 'Follow your device',
    icon: '◐',
  },
  {
    value: 'light',
    label: 'Light',
    description: 'Always use light',
    icon: '☀',
  },
  {
    value: 'dark',
    label: 'Dark',
    description: 'Always use dark',
    icon: '☾',
  },
]

export function App() {
  const [themePreference, setThemePreference] = useState<ThemePreference>(DEFAULT_THEME_PREFERENCE)
  const [isLoading, setIsLoading] = useState(true)
  const [isSaving, setIsSaving] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  useEffect(() => {
    let active = true

    void readThemePreference()
      .then(value => {
        if (active) setThemePreference(value)
      })
      .catch(() => {
        if (active) setErrorMessage('Could not load the saved theme. Using System instead.')
      })
      .finally(() => {
        if (active) setIsLoading(false)
      })

    return () => {
      active = false
    }
  }, [])

  useEffect(() => {
    document.documentElement.dataset.theme = themePreference
  }, [themePreference])

  async function updateThemePreference(nextValue: ThemePreference): Promise<void> {
    if (isSaving || nextValue === themePreference) return

    const previousValue = themePreference
    setThemePreference(nextValue)
    setIsSaving(true)
    setErrorMessage(null)

    try {
      await writeThemePreference(nextValue)
    } catch {
      setThemePreference(previousValue)
      setErrorMessage('Could not save the theme. The previous setting was restored.')
    } finally {
      setIsSaving(false)
    }
  }

  const isBusy = isLoading || isSaving

  return (
    <main className="popup-shell" aria-busy={isBusy}>
      <header className="app-header">
        <div className="brand-mark" aria-hidden="true">
          <img src="/images/icon-48.png" alt="" />
        </div>
        <div className="app-heading">
          <p className="eyebrow">Tsuki settings</p>
          <h1>Appearance</h1>
        </div>
        <span className="settings-badge">Theme</span>
      </header>

      <section className="settings-card" aria-labelledby="theme-heading">
        <div className="section-heading">
          <div>
            <h2 id="theme-heading">Color theme</h2>
            <p id="theme-description">Choose how Tsuki should look.</p>
          </div>
          <span className="selection-value">{themePreference}</span>
        </div>

        <fieldset className="theme-grid" aria-describedby="theme-description theme-status">
          <legend className="visually-hidden">Color theme</legend>
          {THEME_OPTIONS.map(option => (
            <label className="theme-option" key={option.value}>
              <input
                type="radio"
                name="theme-preference"
                value={option.value}
                checked={themePreference === option.value}
                disabled={isBusy}
                onChange={() => void updateThemePreference(option.value)}
              />
              <span className="theme-option-content">
                <span className="theme-option-icon" aria-hidden="true">
                  {option.icon}
                </span>
                <strong>{option.label}</strong>
                <small>{option.description}</small>
              </span>
            </label>
          ))}
        </fieldset>

        <div className="theme-preview" aria-hidden="true">
          <div className="preview-toolbar">
            <span />
            <span />
            <span />
          </div>
          <div className="preview-content">
            <div className="preview-sidebar" />
            <div className="preview-copy">
              <span className="preview-title" />
              <span />
              <span />
            </div>
          </div>
        </div>

        <p
          id="theme-status"
          className={errorMessage ? 'status-message status-message-error' : 'status-message'}
          role={errorMessage ? 'alert' : 'status'}
          aria-live="polite"
        >
          {errorMessage ?? (isLoading ? 'Loading preference…' : isSaving ? 'Saving…' : '')}
        </p>
      </section>

      <footer className="app-footer">
        <span className="sync-indicator" aria-hidden="true" />
        Theme preferences sync with your Chrome profile.
      </footer>
    </main>
  )
}
