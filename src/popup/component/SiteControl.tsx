interface ISiteControlProps {
  readonly disabled: boolean
  readonly enabled: boolean
  readonly isLoading: boolean
  readonly siteLabel?: string
  readonly onChange: (enabled: boolean) => void
}

export function SiteControl({
  disabled,
  enabled,
  isLoading,
  siteLabel,
  onChange,
}: ISiteControlProps) {
  return (
    <div className="setting-row">
      <div className="setting-copy">
        <h2>Use Tsuki on this site</h2>
        <p>{isLoading ? 'Checking current page…' : (siteLabel ?? 'Not available here')}</p>
      </div>

      <label className="switch-control">
        <span className="visually-hidden">Use Tsuki on this site</span>
        <input
          type="checkbox"
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
