import { useStateValue, useViewModel } from '@guanghechen/react-viewmodel'
import React from 'react'
import type { NavigateFunction } from 'react-router-dom'
import { useNavigate } from 'react-router-dom'
import { usePersistAsync } from '@/common/hook/usePersistAsync'
import { universalStorage } from '@/common/util/storage'
import { useMermaidSyncThemeEffect } from '@/hook/useMermaidSyncThemeEffect'
import { ServerCustomEventType } from '@/shared/types'
import type { IResponsePayloadFileChanged, IResponsePayloadFileSwitch } from '@/shared/types'
import type { IFileContext } from './context'
import { FileViewContextType } from './context'
import type { IFileViewData } from './types'
import { FileViewViewModel } from './viewmodel'

const storageKey: string = '#/view/file'

interface ISideEffectProps {
  readonly viewmodel: FileViewViewModel
}

export const FileViewProvider: React.FC<{ children: React.ReactNode }> = props => {
  const viewmodel: FileViewViewModel | null = useViewModel<FileViewViewModel>(async () => {
    const rawViewData = await universalStorage.getContext<Partial<IFileViewData>>(storageKey)
    const viewData: IFileViewData = FileViewViewModel.normalize(rawViewData)
    const usp = new URLSearchParams(window.location.search)
    const filepath: string | null = decodeURIComponent(usp.get('filepath') || '') || null
    return new FileViewViewModel({
      filepath: filepath ?? viewData.filepath,
      filepathHistory: viewData.filepathHistory,
    })
  })
  const context: IFileContext | null = React.useMemo<IFileContext | null>(
    () => (viewmodel ? { viewmodel } : null),
    [viewmodel],
  )

  if (!viewmodel || !context) return <React.Fragment />

  return (
    <React.Fragment>
      <FileViewContextType.Provider value={context}>{props.children}</FileViewContextType.Provider>
      <SideEffect viewmodel={viewmodel} />
    </React.Fragment>
  )
}
FileViewProvider.displayName = 'FileViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel } = props

  usePersistAsync(viewmodel, storageKey, [viewmodel.filepath$, viewmodel.filepathHistory$])
  useHMR(viewmodel)
  useUrlParams(viewmodel)
  useHistoryTracking(viewmodel)
  useMermaidSyncThemeEffect()

  return <React.Fragment />
}
SideEffect.displayName = 'FileViewSideEffect'

// /////////////////////////////////////////////////////////////////////////////////////////////////

const useHMR = (viewmodel: FileViewViewModel): void => {
  const navigate = useNavigate()
  const navigateRef = React.useRef<NavigateFunction>(navigate)
  navigateRef.current = navigate

  React.useEffect(() => {
    const meta = import.meta as any
    if (!meta.hot) return

    let unsubscribed: boolean = false

    const handleFileChanged = (data: IResponsePayloadFileChanged): void => {
      if (unsubscribed) return

      const filepath: string | null = viewmodel.filepath$.getSnapshot()
      if (filepath === data.filepath) {
        viewmodel.markFilepathDirty()
      }
    }

    const handleFileSwitchAsk = (data: IResponsePayloadFileSwitch): void => {
      if (unsubscribed) return

      // Send file_switch event to tsuki
      window.postMessage({
        action: '@@tsuki-current@@',
        tsuki: {
          event: 'file_switch',
          payload: {
            workspace: data.workspace,
            filepath: data.filepath,
          },
        },
      })
    }

    const handleFileSwitch = (data: IResponsePayloadFileSwitch): void => {
      if (unsubscribed) return

      if (data.workspace && data.filepath) {
        meta.hot.off(ServerCustomEventType.FILE_CHANGED, handleFileChanged)
        meta.hot.off(ServerCustomEventType.FILE_SWITCH_ASK, handleFileSwitchAsk)
        void navigateRef.current(
          `/ws/${data.workspace}?filepath=${encodeURIComponent(data.filepath)}`,
        )
        return
      }

      const filepath: string | null = viewmodel.filepath$.getSnapshot()
      if (data.filepath !== filepath) viewmodel.filepath$.next(data.filepath)
      else viewmodel.markFilepathDirty()

      window.postMessage({
        action: '@@tsuki-current@@',
        tsuki: {
          event: 'focus_me',
          payload: {},
        },
      })
    }

    // Listen to window message for FILE_SWITCH
    const handleWindowMessage = (event: MessageEvent): void => {
      if (unsubscribed) return
      if (event.source !== window || !event.data) return
      if (event.data.action === 'FILE_SWITCH') {
        handleFileSwitch(event.data.payload)
      }
    }

    meta.hot.on(ServerCustomEventType.FILE_CHANGED, handleFileChanged)
    meta.hot.on(ServerCustomEventType.FILE_SWITCH_ASK, handleFileSwitchAsk)
    window.addEventListener('message', handleWindowMessage)

    return () => {
      unsubscribed = true
      meta.hot.off(ServerCustomEventType.FILE_CHANGED, handleFileChanged)
      meta.hot.off(ServerCustomEventType.FILE_SWITCH_ASK, handleFileSwitchAsk)
      window.removeEventListener('message', handleWindowMessage)
    }
  }, [viewmodel])
}

const useUrlParams = (viewmodel: FileViewViewModel): void => {
  const filepath: string | null = useStateValue(viewmodel.filepath$)

  React.useEffect(() => {
    const usp = new URLSearchParams(window.location.search)
    usp.delete('workspace')
    usp.delete('filepath')

    if (filepath) usp.set('filepath', encodeURIComponent(filepath))
    const newUrl = `${window.location.pathname}?${usp.toString()}`
    window.history.replaceState(null, '', newUrl)
  }, [filepath])
}

const useHistoryTracking = (viewmodel: FileViewViewModel): void => {
  const filepath: string | null = useStateValue(viewmodel.filepath$)

  React.useEffect(() => {
    if (filepath) {
      viewmodel.addToHistory(filepath)
    }
  }, [filepath, viewmodel])
}
