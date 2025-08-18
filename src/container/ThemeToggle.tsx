import type { ISetState } from '@guanghechen/react-viewmodel'
import React from 'react'
import { SiteTheme, useSetSiteTheme, useSiteTheme } from '@/context/site'

export const ThemeToggle: React.FC = () => {
  const theme: SiteTheme = useSiteTheme()
  const setTheme: ISetState<SiteTheme> = useSetSiteTheme()
  const isDark: boolean = theme === SiteTheme.DARKEN

  const onToggleTheme = React.useCallback(() => {
    setTheme(t => (t === SiteTheme.DARKEN ? SiteTheme.LIGHTEN : SiteTheme.DARKEN))
  }, [setTheme])

  return (
    <div className="ml-5 select-none">
      <input
        type="checkbox"
        id="theme-toggle"
        className="hidden"
        checked={isDark}
        onChange={onToggleTheme}
      />
      <label
        htmlFor="theme-toggle"
        className="relative flex h-[28px] w-[56px] cursor-pointer items-center justify-between rounded-full bg-gradient-to-r from-sky-300 to-blue-400 p-1 shadow-inner transition-all duration-500 ease-in-out hover:shadow-md active:scale-95 dark:bg-gradient-to-r dark:from-indigo-900 dark:to-purple-900 dark:shadow-gray-700"
      >
        <div className="absolute left-1 h-5 w-5 rounded-full bg-white shadow-md transition-all duration-500 ease-in-out dark:left-[29px] dark:bg-gray-100" />
        <svg
          className="absolute left-[6px] h-4 w-4 text-yellow-400 opacity-100 transition-all duration-300 ease-in-out dark:translate-x-6 dark:opacity-0"
          viewBox="0 0 24 24"
          fill="currentColor"
          xmlns="http://www.w3.org/2000/svg"
        >
          <path d="M12 3a1 1 0 0 1 1 1v1a1 1 0 1 1-2 0V4a1 1 0 0 1 1-1zM19 12a1 1 0 0 1-1 1h-1a1 1 0 1 1 0-2h1a1 1 0 0 1 1 1zM7 12a1 1 0 0 1-1 1H5a1 1 0 1 1 0-2h1a1 1 0 0 1 1 1zM12 19a1 1 0 0 1 1 1v1a1 1 0 1 1-2 0v-1a1 1 0 0 1 1-1zM17.7 16.3a1 1 0 0 1 0 1.4l-.7.7a1 1 0 1 1-1.4-1.4l.7-.7a1 1 0 0 1 1.4 0zM7 17.7a1 1 0 0 1 1.4 0l.7.7a1 1 0 1 1-1.4 1.4l-.7-.7a1 1 0 0 1 0-1.4zM17.7 7a1 1 0 0 1 0 1.4l-.7.7a1 1 0 1 1-1.4-1.4l.7-.7A1 1 0 0 1 17.7 7zM8.4 6.3a1 1 0 0 1 0 1.4l-.7.7a1 1 0 1 1-1.4-1.4l.7-.7a1 1 0 0 1 1.4 0zM12 8a4 4 0 1 1 0 8 4 4 0 0 1 0-8z" />
        </svg>
        <div className="absolute right-[6px] h-4 w-4 rounded-full bg-gray-800/0 transition-all duration-300 ease-in-out dark:bg-gray-800/40">
          <svg
            className="h-4 w-4 text-blue-400 opacity-0 transition-all duration-300 ease-in-out dark:opacity-100"
            viewBox="0 0 24 24"
            fill="currentColor"
            xmlns="http://www.w3.org/2000/svg"
          >
            <path
              fillRule="evenodd"
              clipRule="evenodd"
              d="M12.979 3.5a.75.75 0 0 0-.958.713c.077 3.267-2.21 6.165-5.397 6.83a.75.75 0 0 0-.565.842C6.575 17.182 10.59 20.5 15 20.5c4.244 0 7.5-3.838 7.5-8.253 0-4.823-4.675-9.092-9.521-8.747zM14.5 17.5a2.5 2.5 0 1 1-5 0 2.5 2.5 0 0 1 5 0zm-1.5-5a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3z"
            />
          </svg>
        </div>
      </label>
    </div>
  )
}

ThemeToggle.displayName = 'ThemeToggle'
