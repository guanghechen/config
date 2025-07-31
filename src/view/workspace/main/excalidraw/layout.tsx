import type { ExcalidrawElement } from '@excalidraw/excalidraw/element/types'
import type { AppState } from '@excalidraw/excalidraw/types'
import { useEventCallback } from '@guanghechen/react-hooks'
import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { useWorkspaceViewmodel } from '@/context/workspace'
import { useFileResult } from '@/hook/useFileResult'
import type { IJsonFileData } from '@/util/fetch'
import { ExcalidrawComposer } from './composer'

export const ExcalidrawLayout: React.FC = () => {
  const workspaceVM = useWorkspaceViewmodel()
  const workspace: string | null = useStateValue(workspaceVM.workspace$)
  const filepath = useStateValue(workspaceVM.filepath$)
  const tick: number = useStateValue(workspaceVM.filepathDirtyTick$)
  const container = useStateValue(workspaceVM.mainScrollableContainer$)

  const { data, error } = useFileResult<IJsonFileData>(workspace, filepath, tick)

  const [visibleOfScrollToTop, setVisibleOfScrollToTop] = React.useState(false)
  const [isSaving, setIsSaving] = React.useState(false)
  const [saveStatus, setSaveStatus] = React.useState<string | null>(null)

  const onScrollToTop = useEventCallback((): void => {
    if (container) container.scrollTo({ top: 0, behavior: 'smooth' })
  })

  const onSave = useEventCallback(
    async (elements: ReadonlyArray<ExcalidrawElement>, appState: AppState): Promise<void> => {
      if (!workspace || !filepath) return

      setIsSaving(true)
      setSaveStatus(null)

      try {
        const excalidrawData = {
          type: 'excalidraw',
          version: 2,
          source: 'https://excalidraw.com',
          elements: elements,
          appState: {
            gridSize: appState.gridSize,
            viewBackgroundColor: appState.viewBackgroundColor,
          },
        }

        const response = await fetch(
          `/api/excalidraw/save?workspace=${encodeURIComponent(workspace)}&filepath=${encodeURIComponent(filepath)}`,
          {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
            },
            body: JSON.stringify(excalidrawData),
          },
        )

        if (response.ok) {
          setSaveStatus('Saved successfully')
          setTimeout(() => setSaveStatus(null), 2000)
        } else {
          const errorData = await response.json()
          setSaveStatus(`Save failed: ${errorData.error || 'Unknown error'}`)
          setTimeout(() => setSaveStatus(null), 5000)
        }
      } catch (error) {
        setSaveStatus(`Save failed: ${String(error)}`)
        setTimeout(() => setSaveStatus(null), 5000)
      } finally {
        setIsSaving(false)
      }
    },
  )

  React.useEffect(() => {
    if (!container) return

    const onScroll = (): void => {
      if (container.scrollTop > 100) setVisibleOfScrollToTop(true)
      else setVisibleOfScrollToTop(false)
    }

    onScroll()
    container.addEventListener('scroll', onScroll)
    return () => container.removeEventListener('scroll', onScroll)
  }, [container])

  return (
    <div className="w-full pt-8">
      {!!error && (
        <div className="relative mb-12 flex-none bg-gray-100 px-2 py-1.5 text-base text-red-500 dark:bg-gray-800 dark:text-red-400">
          <code>error: {String(error)}</code>
        </div>
      )}
      {!!data && (
        <div className="relative w-full">
          <ExcalidrawComposer content={data?.content} onSave={onSave} />
        </div>
      )}

      {(isSaving || saveStatus) && (
        <div className="fixed top-20 right-4 z-50 flex items-center gap-2 rounded-lg bg-gray-100 bg-opacity-95 px-3 py-2 text-sm shadow-md dark:bg-gray-800 dark:bg-opacity-95">
          {isSaving && (
            <React.Fragment>
              <div className="h-4 w-4 animate-spin rounded-full border-2 border-blue-500 border-t-transparent" />
              <span>Saving...</span>
            </React.Fragment>
          )}
          {saveStatus && !isSaving && (
            <span className={cn(saveStatus.includes('failed') ? 'text-red-500' : 'text-green-500')}>
              {saveStatus}
            </span>
          )}
        </div>
      )}

      <button
        onClick={onScrollToTop}
        className={cn(
          'cursor-pointer fixed bottom-8 right-8 z-[9999] flex h-12 w-12 items-center justify-center rounded-full bg-blue-500 bg-opacity-60 text-white shadow-lg transition-all duration-300 hover:bg-blue-600 hover:bg-opacity-100',
          visibleOfScrollToTop
            ? 'translate-y-0 opacity-90'
            : 'pointer-events-none translate-y-16 opacity-0',
        )}
        title="Scroll to top"
        aria-label="Scroll to top"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          className="h-6 w-6"
          viewBox="0 0 24 24"
          fill="currentColor"
        >
          <path d="M7.41 15.41L12 10.83l4.59 4.58L18 14l-6-6-6 6z" />
        </svg>
      </button>
    </div>
  )
}

ExcalidrawLayout.displayName = 'ExcalidrawLayout'
