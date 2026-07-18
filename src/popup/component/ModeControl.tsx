import type { AppearanceMode } from '@/shared/setting/appearance'

interface IModeOption {
  readonly value: AppearanceMode
  readonly label: string
}

interface IModeControlProps {
  readonly mode: AppearanceMode
  readonly onChange: (mode: AppearanceMode) => void
}

const MODE_OPTIONS: ReadonlyArray<IModeOption> = [
  { value: 'system', label: 'System' },
  { value: 'light', label: 'Light' },
  { value: 'dark', label: 'Dark' },
]

export function ModeControl({ mode, onChange }: IModeControlProps) {
  return (
    <div className="mode-control">
      <span className="control-label">Mode</span>
      <div className="theme-options">
        {MODE_OPTIONS.map(option => (
          <label className="theme-option" key={option.value}>
            <input
              type="radio"
              name="appearance-mode"
              value={option.value}
              checked={mode === option.value}
              onChange={() => onChange(option.value)}
            />
            <span>{option.label}</span>
          </label>
        ))}
      </div>
    </div>
  )
}
