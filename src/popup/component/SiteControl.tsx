import type { ReactElement } from 'react'

interface ISiteControlProps {
  readonly disabled: boolean
  readonly enabled: boolean
  readonly siteLabel: string
  readonly onChange: (enabled: boolean) => void
}

export function SiteControl({
  disabled,
  enabled,
  siteLabel,
  onChange,
}: ISiteControlProps): ReactElement {
  return (
    <div className="setting-row">
      <div className="setting-copy">
        <h2>Use Tsuki on this site</h2>
        <p>{siteLabel}</p>
      </div>

      <label className="switch-control">
        <span className="visually-hidden">Use Tsuki on this site</span>
        <input
          type="checkbox"
          // biome-ignore lint/a11y/useAriaPropsForRole: native checkbox already exposes its checked state
          role="switch"
          checked={enabled}
          disabled={disabled}
          onChange={event => onChange(event.target.checked)}
        />
        <span className="switch-track" aria-hidden="true" />
      </label>
    </div>
  )
}
