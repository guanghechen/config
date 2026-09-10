import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from '@/common/util/clsx'
import React from 'react'
import { CheckIcon, DarkModeIcon, LightModeIcon } from '@/common/component/icon/material'
import { SiteTheme, type SiteThemePreference, useSiteViewmodel } from '@/context/site'

const DeviceThemeIcon: typeof LightModeIcon = ({ className }) => (
  <svg
    className={className}
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth={2}
    aria-hidden="true"
  >
    <rect x="3" y="4" width="18" height="13" rx="2" />
    <path d="M8 21h8M12 17v4" />
  </svg>
)

const themeOptions: ReadonlyArray<{
  value: SiteThemePreference
  label: string
  icon: typeof LightModeIcon
}> = [
  { value: 'system', label: 'Follow device', icon: DeviceThemeIcon },
  { value: SiteTheme.LIGHTEN, label: 'Light', icon: LightModeIcon },
  { value: SiteTheme.DARKEN, label: 'Dark', icon: DarkModeIcon },
]

export const ThemeToggle: React.FC = () => {
  const viewmodel = useSiteViewmodel()
  const theme = useStateValue(viewmodel.themePreference$)
  const groupName = React.useId()
  const [isOpen, setIsOpen] = React.useState(false)
  const rootRef = React.useRef<HTMLDivElement>(null)
  const triggerRef = React.useRef<HTMLButtonElement>(null)
  const panelRef = React.useRef<HTMLDivElement>(null)
  const selected = themeOptions.find(option => option.value === theme) ?? themeOptions[0]
  const Icon = selected.icon

  React.useEffect(() => {
    if (!isOpen) return
    panelRef.current?.querySelector<HTMLInputElement>('input:checked')?.focus()
    const close = (event: PointerEvent): void => {
      if (event.target instanceof Node && !rootRef.current?.contains(event.target)) setIsOpen(false)
    }
    document.addEventListener('pointerdown', close)
    return () => document.removeEventListener('pointerdown', close)
  }, [isOpen])

  return (
    <div
      ref={rootRef}
      className="relative font-sans"
      onKeyDown={event => {
        if (event.key === 'Escape' && isOpen) {
          event.preventDefault()
          setIsOpen(false)
          triggerRef.current?.focus()
        }
      }}
      onBlur={event => {
        if (
          event.relatedTarget instanceof Node &&
          !event.currentTarget.contains(event.relatedTarget)
        )
          setIsOpen(false)
      }}
    >
      <button
        ref={triggerRef}
        type="button"
        aria-label={`Theme: ${selected.label}`}
        title={`Theme: ${selected.label}`}
        aria-haspopup="dialog"
        aria-expanded={isOpen}
        aria-controls={isOpen ? groupName : undefined}
        onClick={() => setIsOpen(open => !open)}
        className="flex h-8 w-8 items-center justify-center rounded-lg text-gray-500 transition-colors hover:bg-gray-200/60 hover:text-gray-900 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-500 dark:text-gray-400 dark:hover:bg-gray-700 dark:hover:text-white"
      >
        <Icon className="h-4 w-4" />
      </button>
      {isOpen && (
        <div
          ref={panelRef}
          id={groupName}
          role="dialog"
          aria-label="Appearance"
          className="absolute right-0 top-full z-50 mt-2 w-48 max-w-[calc(100vw-2rem)] min-w-0 rounded-xl border border-gray-200 bg-white p-2 shadow-lg dark:border-gray-700 dark:bg-gray-900"
        >
          <div className="px-3 pb-2 pt-1 text-xs font-medium text-gray-500 dark:text-gray-400">
            Appearance
          </div>
          <div role="radiogroup" aria-label="Theme" className="space-y-1">
            {themeOptions.map(option => {
              const Icon = option.icon
              const selected = option.value === theme
              return (
                <label
                  key={option.value}
                  className={cn(
                    'relative flex cursor-pointer items-center gap-3 rounded-lg px-3 py-2 text-sm transition-colors',
                    'has-[:focus-visible]:outline-2 has-[:focus-visible]:outline-offset-2 has-[:focus-visible]:outline-blue-500',
                    selected
                      ? 'bg-blue-50 text-blue-700 dark:bg-blue-500/15 dark:text-blue-300'
                      : 'text-gray-600 hover:bg-gray-100 dark:text-gray-300 dark:hover:bg-gray-700/60',
                  )}
                >
                  <input
                    type="radio"
                    name={groupName}
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
        </div>
      )}
    </div>
  )
}

ThemeToggle.displayName = 'ThemeToggle'
