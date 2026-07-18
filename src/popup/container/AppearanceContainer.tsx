import { AgentBridgeControl } from '../component/AgentBridgeControl'
import { AppHeader } from '../component/AppHeader'
import { ModeControl } from '../component/ModeControl'
import { SiteControl } from '../component/SiteControl'
import { StatusMessage } from '../component/StatusMessage'
import { ThemeControl } from '../component/ThemeControl'
import { useAgentBridge } from '../hook/useAgentBridge'
import { useAppearance } from '../hook/useAppearance'

export function AppearanceContainer() {
  const appearance = useAppearance()
  const agentBridge = useAgentBridge(appearance.pageStatus)

  return (
    <main className="popup-shell" aria-busy={appearance.isBusy || agentBridge.isBusy}>
      <AppHeader />

      <section className="settings-panel" aria-label="Appearance settings">
        {appearance.pageStatus ? (
          <>
            <SiteControl
              disabled={appearance.isBusy}
              enabled={appearance.pageStatus.enabled}
              siteLabel={appearance.pageStatus.label}
              onChange={appearance.updatePageEnabled}
            />
            <div className="settings-divider" />
          </>
        ) : null}

        <fieldset
          className="appearance-setting"
          aria-describedby="appearance-description appearance-status"
          disabled={appearance.appearanceControlDisabled}
        >
          <legend className="visually-hidden">Appearance</legend>
          <div className="appearance-heading">
            <h2>Appearance</h2>
            <p id="appearance-description">Choose the mode and color themes.</p>
          </div>

          <ModeControl mode={appearance.appearanceSettings.mode} onChange={appearance.updateMode} />
          <ThemeControl
            settings={appearance.appearanceSettings}
            onChange={appearance.updateTheme}
          />
        </fieldset>
      </section>

      <AgentBridgeControl bridge={agentBridge} />
      <StatusMessage error={appearance.errorMessage} message={appearance.statusMessage} />
    </main>
  )
}
