import { Computed, useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import type { NavigateFunction } from 'react-router-dom'
import { useNavigate } from 'react-router-dom'
import { useSingleton } from '@/hook/useSingleton'
import { ServerCustomEventType } from '@/shared/types'
import type {
  IResponsePayloadFileChanged,
  IResponsePayloadFileSwitch,
  Mutable,
} from '@/shared/types'
import type { IFileContext } from './context'
import { FileViewContextType } from './context'
import type { IFileViewData } from './types'
import { FileViewViewModel } from './viewmodel'

const storageKey: string = '#/view/file'

interface ISideEffectProps {
  readonly viewmodel: FileViewViewModel
}

export const FileViewProvider: React.FC<{ children: React.ReactNode }> = props => {
  const viewmodel: FileViewViewModel | null = useSingleton<FileViewViewModel>(() => {
    const rawViewData: Mutable<Partial<IFileViewData>> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )
    const viewData: IFileViewData = FileViewViewModel.normalize(rawViewData)
    const usp = new URLSearchParams(window.location.search)
    const filepath: string | null = decodeURIComponent(usp.get('filepath') || '') || null
    return new FileViewViewModel({
      filepath: filepath ?? viewData.filepath,
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
      <HmrSideEffect viewmodel={viewmodel} />
    </React.Fragment>
  )
}
FileViewProvider.displayName = 'FileViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

const HmrSideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel } = props
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

    const handleFileSwitch = (data: IResponsePayloadFileSwitch): void => {
      if (unsubscribed) return

      if (data.workspace && data.filepath) {
        meta.hot.off(ServerCustomEventType.FILE_CHANGED, handleFileChanged)
        meta.hot.off(ServerCustomEventType.FILE_SWITCHED, handleFileSwitch)
        void navigateRef.current(
          `/ws/${data.workspace}?filepath=${encodeURIComponent(data.filepath)}`,
        )
        return
      }

      const filepath: string | null = viewmodel.filepath$.getSnapshot()
      if (data.filepath !== filepath) viewmodel.filepath$.next(data.filepath)
      else viewmodel.markFilepathDirty()

      window.postMessage({
        action: '@@tsuki-event@@',
        tsuki: {
          event: 'focus_me',
          payload: {},
        },
      })
    }

    meta.hot.on(ServerCustomEventType.FILE_CHANGED, handleFileChanged)
    meta.hot.on(ServerCustomEventType.FILE_SWITCHED, handleFileSwitch)
    return () => {
      unsubscribed = true
      meta.hot.off(ServerCustomEventType.FILE_CHANGED, handleFileChanged)
      meta.hot.off(ServerCustomEventType.FILE_SWITCHED, handleFileSwitch)
    }
  }, [viewmodel])

  return <React.Fragment />
}
HmrSideEffect.displayName = 'FileViewHmrSideEffect'

// /////////////////////////////////////////////////////////////////////////////////////////////////

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel } = props

  usePersistent(viewmodel)
  useUrlParams(viewmodel)

  return <React.Fragment />
}
SideEffect.displayName = 'FileViewSideEffect'

// /////////////////////////////////////////////////////////////////////////////////////////////////

const usePersistent = (viewmodel: FileViewViewModel): void => {
  React.useEffect(() => {
    const computed = Computed.fromObservables([viewmodel.filepath$], () => {
      const data: IFileViewData = viewmodel.dump()
      window.localStorage.setItem(storageKey, JSON.stringify(data))
    })
    return (): void => {
      computed.dispose()
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
