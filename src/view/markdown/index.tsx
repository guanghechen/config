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
  const [workspace, setWorkspace] = React.useState<string | null>(() => {
    const queryParams = new URLSearchParams(window.location.search)
    return decodeURIComponent(queryParams.get('workspace') || '') || null
  })
  const filepathRef = React.useRef<string>(filepath)
  const workspaceRef = React.useRef<string | null>(workspace)

  const { data, error } = useFileResult(workspace, filepath, tick)
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
    workspaceRef.current = workspace
    if (inputRef.current) inputRef.current.value = filepath

    const queryParams = new URLSearchParams(window.location.search)
    if (workspace) queryParams.set('workspace', encodeURIComponent(workspace))
    if (filepath) queryParams.set('filepath', encodeURIComponent(filepath))
    const newUrl = `${window.location.pathname}?${queryParams.toString()}`
    window.history.replaceState(null, '', newUrl)
  }, [workspace, filepath])

  React.useEffect(() => {
    const meta = import.meta as any
    if (meta.hot) {
      meta.hot.on(ServerCustomEventType.FILE_CHANGED, (data: IResponsePayloadFileChanged): void => {
        if (data.workspace !== workspaceRef.current || data.filepath === filepathRef.current) {
          setTick(tick => tick + 1)
        }
      })
      meta.hot.on(ServerCustomEventType.FILE_SWITCHED, (data: IResponsePayloadFileSwitch): void => {
        if (data.workspace !== workspaceRef.current || data.filepath !== filepathRef.current) {
          setFilepath(data.filepath)
          setWorkspace(data.workspace)
        } else {
          setTick(tick => tick + 1)
        }
      })
    }
  }, [])

  return (
    <div className="box-border flex h-screen w-screen flex-col bg-[#fdfdfd] font-['Maple_Mono_NF_CN','Roboto_Mono',monospace,sans-serif] text-gray-800 shadow-md transition-colors duration-300 ease-in-out dark:bg-[#1a1a1a] dark:text-gray-200 [&::-webkit-scrollbar-thumb]:rounded [&::-webkit-scrollbar-thumb]:bg-gray-300 [&::-webkit-scrollbar-thumb]:hover:bg-gray-400 dark:[&::-webkit-scrollbar-thumb]:bg-gray-600 dark:[&::-webkit-scrollbar-thumb]:hover:bg-gray-500 [&::-webkit-scrollbar-track]:bg-gray-100 dark:[&::-webkit-scrollbar-track]:bg-gray-800 [&::-webkit-scrollbar]:w-2">
      <div className="relative flex items-center justify-center bg-[#dfdfdf] p-5 dark:bg-[#252525]">
        <div className="flex w-[800px] items-center">
          <input
            className="mr-2.5 flex-1 rounded border border-gray-300 bg-gray-100 p-2.5 text-base text-gray-800 outline-none transition-colors duration-300 focus:border-blue-500 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-200 dark:focus:border-blue-500"
            ref={inputRef}
            type="text"
            defaultValue={filepath}
            onKeyDown={onInputKeyDown}
          />
          <button
            className="cursor-pointer rounded border-none bg-blue-600 px-5 py-2.5 text-base text-white transition-colors duration-300 hover:bg-blue-700 dark:bg-blue-500 dark:hover:bg-blue-600"
            onClick={onSubmit}
          >
            Load
          </button>
        </div>
        <div className="absolute right-7">
          <ThemeToggle />
        </div>
      </div>
      <div className="flex flex-1 flex-col overflow-auto [&::-webkit-scrollbar-thumb]:rounded [&::-webkit-scrollbar-thumb]:bg-gray-300 [&::-webkit-scrollbar-thumb]:hover:bg-gray-400 dark:[&::-webkit-scrollbar-thumb]:bg-gray-600 dark:[&::-webkit-scrollbar-thumb]:hover:bg-gray-500 [&::-webkit-scrollbar-track]:bg-gray-100 dark:[&::-webkit-scrollbar-track]:bg-gray-800 [&::-webkit-scrollbar]:w-2">
        {!!error && (
          <div className="flex-none bg-gray-100 px-2 py-1.5 text-base text-red-500 dark:bg-gray-800 dark:text-red-400">
            <code>error: {String(error)}</code>
          </div>
        )}
        {!!ast && (
          <div className="my-5 flex flex-1 justify-center">
            <div className="w-[800px]">
              <ReactMarkdown filepath={filepath} ast={ast} theme={theme} />
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
