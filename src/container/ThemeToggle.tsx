import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from '@/common/util/clsx'
import React from 'react'
import { ChevronRightIcon, DarkModeIcon, LightModeIcon } from '@/common/component/icon/material'
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

interface IProps {
  readonly onSelect?: () => void
}

export const ThemeToggle: React.FC<IProps> = props => {
  const { onSelect } = props
  const viewmodel = useSiteViewmodel()
  const theme: SiteThemePreference = useStateValue(viewmodel.themePreference$)
  const [isOpen, setIsOpen] = React.useState(false)

  const handleThemeSelect = React.useCallback(
    (newTheme: SiteThemePreference): void => {
      setIsOpen(false)
      viewmodel.setThemePreference(newTheme)
      onSelect?.()
    },
    [viewmodel, onSelect],
  )

  const handleToggle = React.useCallback((e: React.MouseEvent): void => {
    e.preventDefault()
    e.stopPropagation()
    setIsOpen(prev => !prev)
  }, [])

  const currentThemeOption = React.useMemo(
    () => themeOptions.find(option => option.value === theme),
    [theme],
  )

  return (
    <div className="relative">
      <button
        onClick={handleToggle}
        className={cn(
          'flex items-center px-4 py-3 rounded-md w-full leading-relaxed',
          'transition-colors duration-150 ease-in-out',
          'focus:outline-none',
          'text-gray-600 hover:text-gray-800 dark:text-gray-300 dark:hover:text-gray-100',
          'hover:bg-gray-100 dark:hover:bg-gray-700',
        )}
        title="Select theme"
        aria-expanded={isOpen}
      >
        <div className="flex items-center gap-3 flex-1">
          {currentThemeOption?.icon && (
            <currentThemeOption.icon className="h-4 w-4 flex-shrink-0" />
          )}
          <span className="text-sm text-gray-700 dark:text-gray-200 truncate">
            {currentThemeOption?.label}
          </span>
        </div>
        <ChevronRightIcon
          className={cn('h-4 w-4 flex-shrink-0 transition-transform duration-150')}
        />
      </button>

      {isOpen && (
        <React.Fragment>
          <div className="absolute top-0 left-full ml-1 w-44 bg-white dark:bg-gray-800 rounded-md border border-gray-200 dark:border-gray-600 shadow-lg z-50">
            {themeOptions.map(option => {
              const IconComponent = option.icon
              return (
                <button
                  key={option.value}
                  aria-pressed={option.value === theme}
                  onClick={() => handleThemeSelect(option.value)}
                  className={cn(
                    'w-full text-left px-4 py-3 text-sm leading-relaxed hover:bg-gray-100 dark:hover:bg-gray-700 flex items-center gap-3 transition-colors duration-150',
                    option.value === theme
                      ? 'bg-blue-50 dark:bg-blue-900/20 text-blue-700 dark:text-blue-300'
                      : 'text-gray-700 dark:text-gray-300',
                  )}
                >
                  <IconComponent className="h-4 w-4 flex-shrink-0" />
                  <span className="truncate">{option.label}</span>
                </button>
              )
            })}
          </div>
          <div className="fixed inset-0 z-40" onClick={() => setIsOpen(false)} />
        </React.Fragment>
      )}
    </div>
  )
}

ThemeToggle.displayName = 'ThemeToggle'
