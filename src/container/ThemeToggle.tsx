import { css } from '@emotion/css'
import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { SiteTheme, useSiteViewmodel } from '@/context/site'

export const ThemeToggle: React.FC = () => {
  const viewmodel = useSiteViewmodel()
  const theme: SiteTheme = useStateValue(viewmodel.theme$)

  const onToggleTheme = React.useCallback(() => {
    viewmodel.theme$.setState(t => (t === SiteTheme.DARKEN ? SiteTheme.LIGHTEN : SiteTheme.DARKEN))
  }, [viewmodel])

  return (
    <div className={toggleClasses.container}>
      <input
        type="checkbox"
        id="theme-toggle"
        className={toggleClasses.toggle}
        checked={theme === SiteTheme.DARKEN}
        onChange={onToggleTheme}
      />
      <label htmlFor="theme-toggle" className={toggleClasses.label}>
        <svg
          className={toggleClasses.sun}
          width="24"
          height="24"
          viewBox="0 0 24 24"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
        >
          <circle cx="12" cy="12" r="4" stroke="currentColor" strokeWidth="2" />
          <path
            d="M12 5V3M12 21v-2M5 12H3m18 0h-2m-2.121-7.879l-1.414 1.414M8.535 15.465L7.12 16.88m0-11.314l1.415 1.414m7.07 7.071l1.414 1.414"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
          />
        </svg>
        <svg
          className={toggleClasses.moon}
          width="24"
          height="24"
          viewBox="0 0 24 24"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
        >
          <path
            d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
      </label>
    </div>
  )
}

const toggleClasses = {
  container: css({
    marginLeft: '20px',
    userSelect: 'none',
  }),
  toggle: css({
    opacity: 0,
    position: 'absolute',
    '&:checked + label': {
      background: '#383838',
      '& svg:first-of-type': {
        // sun
        transform: 'translateX(24px)',
        opacity: 0,
      },
      '& svg:last-of-type': {
        // moon
        transform: 'translateX(0)',
        opacity: 1,
      },
    },
  }),
  label: css({
    cursor: 'pointer',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: '5px',
    position: 'relative',
    width: '50px',
    height: '26px',
    background: '#83d8ff',
    borderRadius: '50px',
    transition: 'background 0.5s ease',
    '&:active': {
      transform: 'scale(0.95)',
    },
  }),
  sun: css({
    position: 'absolute',
    left: '4px',
    color: '#fff',
    transform: 'translateX(0)',
    opacity: 1,
    transition: 'all 0.3s ease',
    '& circle': {
      fill: '#fff',
    },
  }),
  moon: css({
    position: 'absolute',
    right: '4px',
    color: '#fff',
    transform: 'translateX(0)',
    opacity: 0,
    transition: 'all 0.3s ease',
    '& path': {
      fill: '#fff',
    },
  }),
}
