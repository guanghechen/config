import { css } from '@emotion/css'
import { useEventCallback } from '@guanghechen/react-hooks'
import { useStateValue } from '@guanghechen/react-viewmodel'
import type { Root } from '@yozora/ast'
import React from 'react'
import { ReactMarkdown } from '@/component/markdown'
import type { SiteTheme } from '@/context/site'
import { useSiteContext } from '@/context/site'
import { useFileResult } from '@/hook/useFileResult'

export const MarkdownView: React.FC = () => {
  const siteViewModel = useSiteContext().viewmodel
  const theme: SiteTheme = useStateValue(siteViewModel.theme$)

  const [tick, setTick] = React.useState<number>(0)
  const [history, setHistory] = React.useState<string[]>([])
  const [historyIndex, setHistoryIndex] = React.useState<number>(-1)
  const inputRef = React.useRef<HTMLInputElement>(null)
  const [filepath, setFilepath] = React.useState<string>(() => {
    const queryParams = new URLSearchParams(window.location.search)
    return decodeURIComponent(queryParams.get('filepath') || '')
  })

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

  React.useEffect(() => {
    const queryParams = new URLSearchParams(window.location.search)
    queryParams.set('filepath', encodeURIComponent(filepath))
    const newUrl = `${window.location.pathname}?${queryParams.toString()}`
    window.history.replaceState(null, '', newUrl)
  }, [filepath])

  React.useEffect(() => {
    const meta = import.meta as any
    if (meta.hot) {
      meta.hot.on('guanghechen', (msg: unknown): void => {
        console.log('received from vite server', msg)
      })
    }
  }, [])

  return (
    <div className={classes.container}>
      <div className={classes.fileSelect}>
        <div className={classes.fileSelectInner}>
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
      </div>
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
  )
}

const classes = {
  container: css({
    display: 'flex',
    flexDirection: 'column',
    width: '100vw',
    height: '100vh',
    boxSizing: 'border-box',
    fontFamily: "'Maple Mono NF CN', 'Roboto Mono', monospace, sans-serif",
    backgroundColor: '#fdfdfd',
    boxShadow: '0 4px 6px rgba(0, 0, 0, 0.1)',
    transition: 'background-color 0.3s ease',
  }),
  fileSelect: css({
    flex: '0 0 auto',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    padding: '20px',
    backgroundColor: '#dfdfdf',
  }),
  fileSelectInner: css({
    display: 'flex',
    alignItems: 'center',
    width: '800px',
  }),
  fileSelectInput: css({
    flex: 1,
    padding: '10px',
    borderRadius: '4px',
    border: '1px solid #ccc',
    fontSize: '16px',
    marginRight: '10px',
    outline: 'none',
    transition: 'border-color 0.3s',
    '&:focus': {
      borderColor: '#007BFF',
    },
  }),
  fileSelectSubmitButton: css({
    padding: '10px 20px',
    borderRadius: '4px',
    border: 'none',
    backgroundColor: '#007BFF',
    color: '#fff',
    fontSize: '16px',
    cursor: 'pointer',
    transition: 'background-color 0.3s',
    '&:hover': {
      backgroundColor: '#0056b3',
    },
  }),
  error: css({
    padding: '6px 8px',
    fontSize: '1rem',
    color: '#EF4444',
    background: '#EEEEEE',
  }),
  preview: css({
    flex: '1 1 auto',
    display: 'flex',
    justifyContent: 'center',
    overflow: 'auto',
    margin: '20px 0',
  }),
  previewInner: css({
    width: '800px',
  }),
}
