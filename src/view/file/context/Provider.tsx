import { useEventCallback } from '@guanghechen/react-hooks'
import { Computed, useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useNavigate } from 'react-router-dom'
import { useViewModelCleanup } from '@/hook/useViewModelCleanup'
import { ServerCustomEventType } from '@/shared/types'
import type {
  IResponsePayloadFileChanged,
  IResponsePayloadFileSwitch,
  Mutable,
} from '@/shared/types'
import type { IFileContext } from './context'
import { FileContextType } from './context'
import type { IFileData } from './types'
import { FileViewModel } from './viewmodel'

const storageKey: string = '#/view/file'

export const FileViewProvider: React.FC<{ children: React.ReactNode }> = props => {
  const [viewmodel] = React.useState<FileViewModel>(() => {
    const initialData: Mutable<Partial<IFileData>> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )
    const usp = new URLSearchParams(window.location.search)
    const filepath: string | null = decodeURIComponent(usp.get('filepath') || '') || null
    const viewmodel = FileViewModel.fromData({
      filepath: filepath ?? initialData.filepath,
    })
    return viewmodel
  })

  const context: IFileContext = React.useMemo<IFileContext>(() => ({ viewmodel }), [viewmodel])

  return (
    <React.Fragment>
      <FileContextType.Provider value={context}>{props.children}</FileContextType.Provider>
      <SideEffect viewmodel={viewmodel} />
    </React.Fragment>
  )
}
FileViewProvider.displayName = 'FileViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectProps {
  readonly viewmodel: FileViewModel
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel } = props
  const filepath: string | null = useStateValue(viewmodel.filepath$)

  const navigate = useNavigate()
  const hmr = useEventCallback((): void => {
    const meta = import.meta as any
    if (meta.hot) {
      let unsubscribed: boolean = false

      const handleFileChanged = (data: IResponsePayloadFileChanged): void => {
        if (unsubscribed) return

        viewmodel.filepath$.next(data.filepath, { force: true })
        if (data.filepath === filepath) viewmodel.markFilepathDirty()
      }

      const handleFileSwitch = (data: IResponsePayloadFileSwitch): void => {
        if (unsubscribed) return

        if (data.workspace && data.filepath) {
          unsubscribed = true
          meta.hot.off(ServerCustomEventType.FILE_CHANGED, handleFileChanged)
          meta.hot.off(ServerCustomEventType.FILE_SWITCHED, handleFileSwitch)
          void navigate(`/ws/${data.workspace}?filepath=${encodeURIComponent(data.filepath)}`)
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
    }
  })

  React.useEffect(() => {
    const computed = Computed.fromObservables([viewmodel.filepath$], () => {
      const data: IFileData = viewmodel.dump()
      window.localStorage.setItem(storageKey, JSON.stringify(data))
    })
    return (): void => {
      computed.dispose()
    }
  }, [viewmodel])

  React.useEffect(() => {
    hmr()
  }, [hmr])

  React.useEffect(() => {
    const usp = new URLSearchParams(window.location.search)
    usp.delete('workspace')
    usp.delete('filepath')

    if (filepath) usp.set('filepath', encodeURIComponent(filepath))
    const newUrl = `${window.location.pathname}?${usp.toString()}`
    window.history.replaceState(null, '', newUrl)
  }, [filepath])

  useViewModelCleanup(viewmodel)

  return <React.Fragment />
}

SideEffect.displayName = 'FileViewSideEffect'
