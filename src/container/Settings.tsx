import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { CheckIcon, DarkModeIcon, LightModeIcon } from '@/common/component/icon/material'
import type { DarkPalette, IColorPalette, LightPalette } from '@/common/style/palette'
import { DARK_PALETTES, LIGHT_PALETTES } from '@/common/style/palette'
import cn from '@/common/util/clsx'
import { SiteTheme, type SiteThemePreference, useSiteViewmodel } from '@/context/site'

const DeviceThemeIcon: typeof LightModeIcon = ({ className }) => (
  <svg
    aria-hidden="true"
    className={className}
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth={2}
  >
    <rect x="3" y="4" width="18" height="13" rx="2" />
    <path d="M8 21h8M12 17v4" />
  </svg>
)

const SettingsGearIcon: typeof LightModeIcon = ({ className }) => (
  <svg
    aria-hidden="true"
    className={className}
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth={2}
    strokeLinecap="round"
    strokeLinejoin="round"
  >
    <path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.09a2 2 0 0 1 1 1.74v.5a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.38a2 2 0 0 0-.73-2.73l-.15-.09a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z" />
    <circle cx="12" cy="12" r="3" />
  </svg>
)

const themeOptions: ReadonlyArray<{
  readonly value: SiteThemePreference
  readonly label: string
  readonly icon: typeof LightModeIcon
}> = [
  { value: 'system', label: 'Follow device', icon: DeviceThemeIcon },
  { value: SiteTheme.LIGHTEN, label: 'Light', icon: LightModeIcon },
  { value: SiteTheme.DARKEN, label: 'Dark', icon: DarkModeIcon },
]

export const Settings: React.FC = () => {
  const viewmodel = useSiteViewmodel()
  const theme = useStateValue(viewmodel.themePreference$)
  const lightPalette = useStateValue(viewmodel.lightPalette$)
  const darkPalette = useStateValue(viewmodel.darkPalette$)
  const dialogRef = React.useRef<HTMLDialogElement>(null)
  const triggerRef = React.useRef<HTMLButtonElement>(null)
  const focusFrameRef = React.useRef<number | null>(null)
  const [isOpen, setIsOpen] = React.useState(false)
  const dialogId = React.useId()
  const titleId = React.useId()
  const themeGroupName = React.useId()
  const lightPaletteGroupName = React.useId()
  const darkPaletteGroupName = React.useId()

  React.useEffect(() => {
    const dialog = dialogRef.current
    if (!dialog) return

    const handleClose = (): void => {
      if (focusFrameRef.current !== null) {
        cancelAnimationFrame(focusFrameRef.current)
        focusFrameRef.current = null
      }
      setIsOpen(false)
      focusFrameRef.current = requestAnimationFrame(() => {
        focusFrameRef.current = null
        triggerRef.current?.focus()
      })
    }
    dialog.addEventListener('close', handleClose)
    return () => {
      dialog.removeEventListener('close', handleClose)
      if (focusFrameRef.current !== null) cancelAnimationFrame(focusFrameRef.current)
      if (dialog.open) dialog.close()
    }
  }, [])

  const openDialog = React.useCallback((): void => {
    const dialog = dialogRef.current
    if (!dialog || dialog.open) return
    dialog.showModal()
    setIsOpen(true)
    focusFrameRef.current = requestAnimationFrame(() => {
      focusFrameRef.current = null
      dialog
        .querySelector<HTMLInputElement>('input[name="' + themeGroupName + '"]:checked')
        ?.focus()
    })
  }, [themeGroupName])

  return (
    <React.Fragment>
      <button
        ref={triggerRef}
        type="button"
        title="Settings"
        aria-label="Settings"
        aria-haspopup="dialog"
        aria-expanded={isOpen}
        aria-controls={dialogId}
        onClick={openDialog}
        className="flex h-8 w-8 items-center justify-center rounded-lg text-[var(--vscode-muted-foreground)] transition-colors hover:bg-[var(--vscode-list-hover-background)] hover:text-[var(--vscode-foreground)] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[var(--vscode-focus-border)]"
      >
        <SettingsGearIcon className="h-4 w-4" />
      </button>

      <dialog
        ref={dialogRef}
        id={dialogId}
        aria-labelledby={titleId}
        onCancel={event => {
          event.preventDefault()
          event.currentTarget.close()
        }}
        onKeyDown={event => {
          event.stopPropagation()
          if (event.key === 'Escape') {
            event.preventDefault()
            event.currentTarget.close()
          }
        }}
        onMouseDown={event => {
          if (event.target === event.currentTarget) event.currentTarget.close()
        }}
        className="m-auto max-h-[calc(100dvh-2rem)] w-[min(42rem,calc(100vw-2rem))] max-w-none overflow-y-auto rounded-xl border border-[var(--vscode-control-border)] bg-[var(--vscode-popover-background)] p-0 text-[var(--vscode-foreground)] shadow-2xl backdrop:bg-black/50"
      >
        <div className="p-5 sm:p-6">
          <div className="flex items-start justify-between gap-4">
            <div>
              <h2 id={titleId} className="text-lg font-semibold">
                Appearance
              </h2>
              <p className="mt-1 text-sm text-[var(--vscode-muted-foreground)]">
                Changes are applied and saved immediately.
              </p>
            </div>
            <button
              type="button"
              aria-label="Close settings"
              title="Close"
              onClick={() => dialogRef.current?.close()}
              className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg text-xl font-normal text-[var(--vscode-muted-foreground)] hover:bg-[var(--vscode-list-hover-background)] hover:text-[var(--vscode-foreground)] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[var(--vscode-focus-border)]"
            >
              ×
            </button>
          </div>

          <fieldset className="mt-6">
            <legend className="text-sm font-semibold">Mode</legend>
            <div className="mt-2 grid grid-cols-1 gap-2 sm:grid-cols-3">
              {themeOptions.map(option => {
                const Icon = option.icon
                const selected = option.value === theme
                return (
                  <label
                    key={option.value}
                    className={cn(
                      'flex cursor-pointer items-center gap-3 rounded-lg border px-3 py-2.5 text-sm transition-colors',
                      'has-[:focus-visible]:outline-2 has-[:focus-visible]:outline-offset-2 has-[:focus-visible]:outline-[var(--vscode-focus-border)]',
                      selected
                        ? 'border-[var(--vscode-accent)] bg-[var(--vscode-list-active-background)]'
                        : 'border-[var(--vscode-border)] hover:bg-[var(--vscode-list-hover-background)]',
                    )}
                  >
                    <input
                      type="radio"
                      name={themeGroupName}
                      value={option.value}
                      checked={selected}
                      onChange={() => viewmodel.setThemePreference(option.value)}
                      className="sr-only"
                    />
                    <Icon className="h-4 w-4 shrink-0" />
                    <span className="flex-1">{option.label}</span>
                    {selected && <CheckIcon className="h-4 w-4 shrink-0" />}
                  </label>
                )
              })}
            </div>
          </fieldset>

          <PaletteFieldset
            legend="Light palette"
            name={lightPaletteGroupName}
            palettes={LIGHT_PALETTES}
            selected={lightPalette}
            onChange={viewmodel.setLightPalette}
          />
          <PaletteFieldset
            legend="Dark palette"
            name={darkPaletteGroupName}
            palettes={DARK_PALETTES}
            selected={darkPalette}
            onChange={viewmodel.setDarkPalette}
          />
        </div>
      </dialog>
    </React.Fragment>
  )
}

Settings.displayName = 'Settings'

interface IPaletteFieldsetProps<T extends LightPalette | DarkPalette> {
  readonly legend: string
  readonly name: string
  readonly palettes: ReadonlyArray<IColorPalette<T>>
  readonly selected: T
  readonly onChange: (palette: T) => void
}

const PaletteFieldset = <T extends LightPalette | DarkPalette>(
  props: IPaletteFieldsetProps<T>,
): React.ReactElement => {
  const { legend, name, palettes, selected, onChange } = props
  return (
    <fieldset className="mt-6">
      <legend className="text-sm font-semibold">{legend}</legend>
      <div className="mt-2 grid grid-cols-1 gap-2 sm:grid-cols-2">
        {palettes.map(palette => {
          const active = palette.id === selected
          const swatches = [
            palette.colors.base,
            palette.colors.surface,
            palette.colors.rose,
            palette.colors.pine,
            palette.colors.iris,
          ]
          return (
            <label
              key={palette.id}
              className={cn(
                'cursor-pointer rounded-lg border p-3 transition-colors',
                'has-[:focus-visible]:outline-2 has-[:focus-visible]:outline-offset-2 has-[:focus-visible]:outline-[var(--vscode-focus-border)]',
                active
                  ? 'border-[var(--vscode-accent)] bg-[var(--vscode-list-active-background)]'
                  : 'border-[var(--vscode-border)] hover:bg-[var(--vscode-list-hover-background)]',
              )}
            >
              <input
                type="radio"
                name={name}
                value={palette.id}
                checked={active}
                onChange={() => onChange(palette.id)}
                className="sr-only"
              />
              <span className="flex items-center gap-3">
                <span className="flex min-w-0 flex-1 items-center gap-2">
                  <span className="truncate text-sm font-medium">{palette.label}</span>
                  {active && <CheckIcon className="h-4 w-4 shrink-0" />}
                </span>
                <span className="flex overflow-hidden rounded border border-black/10 shadow-sm">
                  {swatches.map((color, index) => (
                    <span
                      key={palette.id + '-' + index}
                      className="h-4 w-4"
                      style={{ backgroundColor: color }}
                    />
                  ))}
                </span>
              </span>
            </label>
          )
        })}
      </div>
    </fieldset>
  )
}
