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
          className="absolute left-[6px] h-4 w-4 text-amber-500 opacity-100 transition-all duration-300 ease-in-out dark:translate-x-6 dark:opacity-0"
          viewBox="0 0 24 24"
          fill="currentColor"
          xmlns="http://www.w3.org/2000/svg"
        >
          <path d="M12 3a1 1 0 0 1 1 1v1a1 1 0 1 1-2 0V4a1 1 0 0 1 1-1zM19 12a1 1 0 0 1-1 1h-1a1 1 0 1 1 0-2h1a1 1 0 0 1 1 1zM7 12a1 1 0 0 1-1 1H5a1 1 0 1 1 0-2h1a1 1 0 0 1 1 1zM12 19a1 1 0 0 1 1 1v1a1 1 0 1 1-2 0v-1a1 1 0 0 1 1-1zM17.7 16.3a1 1 0 0 1 0 1.4l-.7.7a1 1 0 1 1-1.4-1.4l.7-.7a1 1 0 0 1 1.4 0zM7 17.7a1 1 0 0 1 1.4 0l.7.7a1 1 0 1 1-1.4 1.4l-.7-.7a1 1 0 0 1 0-1.4zM17.7 7a1 1 0 0 1 0 1.4l-.7.7a1 1 0 1 1-1.4-1.4l.7-.7A1 1 0 0 1 17.7 7zM8.4 6.3a1 1 0 0 1 0 1.4l-.7.7a1 1 0 1 1-1.4-1.4l.7-.7a1 1 0 0 1 1.4 0zM12 8a4 4 0 1 1 0 8 4 4 0 0 1 0-8z" />
        </svg>
        <div className="absolute right-[6px] h-4 w-4 rounded-full bg-gray-800/0 transition-all duration-300 ease-in-out dark:bg-gray-800/40">
          <svg
            className="h-4 w-4 text-gray-200 opacity-0 transition-all duration-300 ease-in-out dark:opacity-100"
            viewBox="0 0 24 24"
            fill="currentColor"
            xmlns="http://www.w3.org/2000/svg"
          >
            <path d="M21.752 15.002A9.718 9.718 0 0118 15.75c-5.385 0-9.75-4.365-9.75-9.75 0-1.33.266-2.597.748-3.752A9.753 9.753 0 003 11.25C3 16.635 7.365 21 12.75 21a9.753 9.753 0 009.002-5.998z" />
          </svg>
        </div>
      </label>
    </div>
  )
}
