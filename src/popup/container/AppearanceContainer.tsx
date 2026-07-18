import { AppHeader } from '../component/AppHeader'
import { ModeControl } from '../component/ModeControl'
import { SiteControl } from '../component/SiteControl'
import { StatusMessage } from '../component/StatusMessage'
import { ThemeControl } from '../component/ThemeControl'
import { useAppearance } from '../hook/useAppearance'

export function AppearanceContainer() {
  const appearance = useAppearance()

  return (
    <main className="popup-shell" aria-busy={appearance.isBusy}>
      <AppHeader />

      <section className="settings-panel" aria-label="Appearance settings">
        <SiteControl
          disabled={appearance.pageControlDisabled}
          enabled={appearance.pageStatus?.enabled ?? false}
          isLoading={appearance.isLoading}
          siteLabel={appearance.pageStatus?.label}
          onChange={appearance.updatePageEnabled}
        />

        <div className="settings-divider" />

        <fieldset
          className="appearance-setting"
          aria-describedby="appearance-description appearance-status"
          disabled={appearance.appearanceControlDisabled}
        >
          <legend>Appearance</legend>
          <p id="appearance-description">Choose the mode and color themes.</p>

          <ModeControl mode={appearance.appearanceSettings.mode} onChange={appearance.updateMode} />
          <ThemeControl
            settings={appearance.appearanceSettings}
            onChange={appearance.updateTheme}
          />
        </fieldset>
      </section>

      <StatusMessage error={appearance.errorMessage} message={appearance.statusMessage} />
    </main>
  )
}
