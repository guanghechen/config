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

  return (
    <fieldset className="min-w-0">
      <legend className="px-2 pb-2 text-xs font-medium text-gray-500 dark:text-gray-400">
        Appearance
      </legend>
      <div className="space-y-1">
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
    </fieldset>
  )
}

ThemeToggle.displayName = 'ThemeToggle'
