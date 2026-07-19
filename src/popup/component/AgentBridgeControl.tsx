import type { AgentGrantKind } from '@/agent/contract'
import type { IAgentBridgeViewModel } from '../hook/useAgentBridge'

interface IAgentBridgeControlProps {
  readonly bridge: IAgentBridgeViewModel
}

export function AgentBridgeControl({ bridge }: IAgentBridgeControlProps) {
  return (
    <section className="settings-panel agent-panel" aria-labelledby="agent-bridge-heading">
      <div className="agent-heading">
        <div>
          <h2 id="agent-bridge-heading">Agent bridge</h2>
          <p>
            {bridge.status.error?.message ??
              (bridge.status.paired ? connectionLabel(bridge.status.connected) : 'Not paired')}
          </p>
        </div>
        {bridge.status.paired ? (
          <button
            className="secondary-button"
            type="button"
            disabled={bridge.isBusy}
            onClick={bridge.unpair}
          >
            Unpair
          </button>
        ) : null}
      </div>

      {bridge.status.paired ? (
        bridge.currentOrigin ? (
          <div className="agent-grant-list">
            <AgentGrantRow
              label="Read access"
              description={bridge.currentOrigin}
              grant="read"
              checked={bridge.isReadGranted}
              disabled={bridge.isBusy}
              onChange={bridge.setGrant}
            />
            <AgentGrantRow
              label="Agent notes"
              description="Session-scoped memory"
              grant="memory"
              checked={bridge.isMemoryGranted}
              disabled={bridge.isBusy || !bridge.isReadGranted}
              onChange={bridge.setGrant}
            />
            <AgentGrantRow
              label="Page actions"
              description="Scroll and highlight only"
              grant="actions"
              checked={bridge.isActionGranted}
              disabled={bridge.isBusy || !bridge.isReadGranted}
              onChange={bridge.setGrant}
            />
          </div>
        ) : null
      ) : (
        <div className="pairing-control">
          <label>
            <span>Pairing code</span>
            <input
              type="password"
              value={bridge.pairingCode}
              disabled={bridge.isBusy}
              autoComplete="off"
              spellCheck={false}
              onChange={event => bridge.setPairingCode(event.target.value)}
            />
          </label>
          <button
            type="button"
            disabled={bridge.isBusy || bridge.pairingCode.trim().length < 8}
            onClick={bridge.pair}
          >
            Pair
          </button>
        </div>
      )}

      {bridge.errorMessage ? (
        <p className="agent-error" role="alert">
          {bridge.errorMessage}
        </p>
      ) : null}
    </section>
  )
}

interface IAgentGrantRowProps {
  readonly checked: boolean
  readonly description: string
  readonly disabled: boolean
  readonly grant: AgentGrantKind
  readonly label: string
  readonly onChange: (grant: AgentGrantKind, allowed: boolean) => void
}

function AgentGrantRow(props: IAgentGrantRowProps) {
  return (
    <label className="agent-grant-row">
      <span className="agent-grant-copy">
        <strong>{props.label}</strong>
        <small>{props.description}</small>
      </span>
      <span className="switch-control">
        <input
          type="checkbox"
          role="switch"
          checked={props.checked}
          disabled={props.disabled}
          onChange={event => props.onChange(props.grant, event.target.checked)}
        />
        <span className="switch-track" aria-hidden="true" />
      </span>
    </label>
  )
}

function connectionLabel(connected: boolean): string {
  return connected ? 'Connected for this browser session' : 'Paired · waiting for local broker'
}
