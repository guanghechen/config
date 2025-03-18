import { css } from '@emotion/css'
import { useEventCallback } from '@guanghechen/react-hooks'
import { useStateValue } from '@guanghechen/react-viewmodel'
import type { Root } from '@yozora/ast'
import React from 'react'
import { ReactMarkdown } from '@/component/markdown'
import { ThemeToggle } from '@/container/ThemeToggle'
import type { SiteTheme } from '@/context/site'
import { useSiteViewmodel } from '@/context/site'
import { useFileResult } from '@/hook/useFileResult'
import { ServerCustomEventType } from '@/shared/types'
import type { IResponsePayloadFileChanged, IResponsePayloadFileSwitch } from '@/shared/types'

export const MarkdownView: React.FC = () => {
  const siteViewModel = useSiteViewmodel()
  const theme: SiteTheme = useStateValue(siteViewModel.theme$)

  const [tick, setTick] = React.useState<number>(0)
  const [history, setHistory] = React.useState<string[]>([])
  const [historyIndex, setHistoryIndex] = React.useState<number>(-1)
  const inputRef = React.useRef<HTMLInputElement>(null)
  const [filepath, setFilepath] = React.useState<string>(() => {
    const queryParams = new URLSearchParams(window.location.search)
    return decodeURIComponent(queryParams.get('filepath') || '')
  })
  const filepathRef = React.useRef<string>(filepath)

  const { data, error } = useFileResult(filepath, tick)
  const ast: Root | undefined = data?.ast

  const onSubmit = useEventCallback(() => {
    if (inputRef.current) {
      const nextFilepath: string = inputRef.current.value
      const currentFilepath: string | undefined = history[historyIndex]
      if (nextFilepath !== currentFilepath) {
        if (historyIndex + 1 < history.length) {
          if (history[historyIndex + 1] !== currentFilepath) {
            setHistory([...history.slice(0, historyIndex + 1), nextFilepath])
          }
          setHistoryIndex(historyIndex + 1)
        } else {
          setHistory([...history, nextFilepath])
          setHistoryIndex(history.length)
        }
      }

      setFilepath(nextFilepath)
      setTick(tick => tick + 1)
    }
  })

  const onInputKeyDown = useEventCallback((e: React.KeyboardEvent<HTMLInputElement>): void => {
    if (e.key === 'Enter') {
      onSubmit()
    } else if (e.key === 'ArrowUp') {
      const nextIndex: number = historyIndex > 0 ? historyIndex - 1 : history.length - 1
      if (nextIndex >= 0) {
        if (inputRef.current) inputRef.current.value = history[nextIndex]
        setHistoryIndex(nextIndex)
      }
    } else if (e.key === 'ArrowDown') {
      const nextIndex: number = historyIndex + 1 < history.length ? historyIndex + 1 : 0
      if (nextIndex < history.length) {
        if (inputRef.current) inputRef.current.value = history[nextIndex]
        setHistoryIndex(nextIndex)
      }
    } else if (e.key === 'Tab') {
      e.preventDefault()
      if (inputRef.current) {
        const currentValue = inputRef.current.value
        const match = history.find(item => item.startsWith(currentValue))
        if (match) {
          inputRef.current.value = match
        }
      }
    }
  })

  // Update filepath in URL
  React.useEffect(() => {
    filepathRef.current = filepath
    if (inputRef.current) inputRef.current.value = filepath

    const queryParams = new URLSearchParams(window.location.search)
    queryParams.set('filepath', encodeURIComponent(filepath))
    const newUrl = `${window.location.pathname}?${queryParams.toString()}`
    window.history.replaceState(null, '', newUrl)
  }, [filepath])

  // Update color scheme based on theme
  React.useEffect(() => {
    document.documentElement.setAttribute('data-color-scheme', theme)
  }, [theme])

  React.useEffect(() => {
    const meta = import.meta as any
    if (meta.hot) {
      meta.hot.on(ServerCustomEventType.FILE_CHANGED, (data: IResponsePayloadFileChanged): void => {
        if (data.filepath === filepathRef.current) {
          setTick(tick => tick + 1)
        }
      })
      meta.hot.on(ServerCustomEventType.FILE_SWITCHED, (data: IResponsePayloadFileSwitch): void => {
        if (data.filepath !== filepathRef.current) {
          setFilepath(data.filepath)
        } else {
          setTick(tick => tick + 1)
        }
      })
    }
  }, [])

  return (
    <div className={classes.container}>
      <div className={classes.header}>
        <div className={classes.fileSelect}>
          <input
            className={classes.fileSelectInput}
            ref={inputRef}
            type="text"
            defaultValue={filepath}
            onKeyDown={onInputKeyDown}
          />
          <button className={classes.fileSelectSubmitButton} onClick={onSubmit}>
            Load
          </button>
        </div>
        <div className={classes.headerActions}>
          <ThemeToggle />{' '}
        </div>
      </div>
      <div className={classes.main}>
        {!!error && (
          <div className={classes.error}>
            <code>error: {String(error)}</code>
          </div>
        )}
        {!!ast && (
          <div className={classes.preview}>
            <div className={classes.previewInner}>
              <ReactMarkdown filepath={filepath} ast={ast} theme={theme} />
            </div>
          </div>
        )}
      </div>
    </div>
  )
}

// Define color scheme CSS
const colorSchemeCSS = `
  :root[data-color-scheme="lighten"] {
    --yo-bg-primary: #fdfdfd;
    --yo-bg-secondary: #f3f4f6;
    --yo-bg-header: #dfdfdf;
    --yo-bg-button: #007BFF;
    --yo-bg-button-hover: #0056b3;
    --yo-bg-error: #EEEEEE;

    --yo-text-primary: #1f2937;
    --yo-text-secondary: #4b5563;
    --yo-text-button: #ffffff;
    --yo-text-error: #EF4444;

    --yo-border-input: #ccc;
    --yo-border-input-focus: #007BFF;

    --yo-shadow: rgba(0, 0, 0, 0.1);
  }

  :root[data-color-scheme="darken"] {
    --yo-bg-primary: #1a1a1a;
    --yo-bg-secondary: #2d2d2d;
    --yo-bg-header: #252525;
    --yo-bg-button: #3b82f6;
    --yo-bg-button-hover: #2563eb;
    --yo-bg-error: #2d2d2d;

    --yo-text-primary: #e5e7eb;
    --yo-text-secondary: #9ca3af;
    --yo-text-button: #ffffff;
    --yo-text-error: #f87171;

    --yo-border-input: #4b5563;
    --yo-border-input-focus: #3b82f6;

    --yo-shadow: rgba(0, 0, 0, 0.25);
  }
`

// Inject the color scheme CSS
const styleElement = document.createElement('style')
styleElement.textContent = colorSchemeCSS
document.head.appendChild(styleElement)

const classes = {
  container: css({
    display: 'flex',
    flexDirection: 'column',
    width: '100vw',
    height: '100vh',
    boxSizing: 'border-box',
    fontFamily: "'Maple Mono NF CN', 'Roboto Mono', monospace, sans-serif",
    backgroundColor: 'var(--yo-bg-primary)',
    color: 'var(--yo-text-primary)',
    boxShadow: '0 4px 6px var(--yo-shadow)',
    transition: 'background-color 0.3s ease, color 0.3s ease',
  }),
  header: css({
    position: 'relative',
    flex: '0 0 auto',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    padding: '20px',
    backgroundColor: 'var(--yo-bg-header)',
  }),
  main: css({
    flex: '1 1 100%',
    display: 'flex',
    flexDirection: 'column',
    overflow: 'auto',
    backgroundColor: 'var(--color-bg-primary)',
  }),
  fileSelect: css({
    display: 'flex',
    alignItems: 'center',
    width: '800px',
  }),
  fileSelectInput: css({
    flex: 1,
    padding: '10px',
    borderRadius: '4px',
    border: '1px solid var(--yo-border-input)',
    backgroundColor: 'var(--yo-bg-secondary)',
    color: 'var(--yo-text-primary)',
    fontSize: '16px',
    marginRight: '10px',
    outline: 'none',
    transition: 'border-color 0.3s, background-color 0.3s, color 0.3s',
    '&:focus': {
      borderColor: 'var(--yo-border-input-focus)',
    },
  }),
  fileSelectSubmitButton: css({
    padding: '10px 20px',
    borderRadius: '4px',
    border: 'none',
    backgroundColor: 'var(--yo-bg-button)',
    color: 'var(--yo-text-button)',
    fontSize: '16px',
    cursor: 'pointer',
    transition: 'background-color 0.3s',
    '&:hover': {
      backgroundColor: 'var(--yo-bg-button-hover)',
    },
  }),
  headerActions: css({
    position: 'absolute',
    right: '28px',
  }),
  error: css({
    flex: '0 0 auto',
    padding: '6px 8px',
    fontSize: '1rem',
    color: 'var(--yo-text-error)',
    background: 'var(--yo-bg-error)',
  }),
  preview: css({
    flex: '1 1 auto',
    display: 'flex',
    justifyContent: 'center',
    margin: '20px 0',
  }),
  previewInner: css({
    width: '800px',
  }),
}
