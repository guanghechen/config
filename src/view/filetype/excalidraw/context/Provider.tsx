import { useViewModel } from '@guanghechen/react-viewmodel'
import React from 'react'
import { toast } from 'react-toastify'
import { usePersistAsync } from '@/hook/usePersistAsync'
import { universalStorage } from '@/util/storage'
import type { IExcalidrawViewContext } from './context'
import { ExcalidrawViewContextType } from './context'
import type { IExcalidrawViewData, ModeEnum } from './types'
import { ExcalidrawViewViewModel } from './viewmodel'

interface IProps {
  readonly content: string | null
  readonly contentError: string | null
  readonly onSaveFile?: (content: string) => void
  readonly mode?: ModeEnum
  readonly storageKeyScope: string
  readonly children: React.ReactNode
}

export const ExcalidrawViewProvider: React.FC<IProps> = props => {
  const { content, contentError, onSaveFile, mode, storageKeyScope, children } = props
  const storageKey = `${storageKeyScope}/filetype/excalidraw`
  const viewmodel: ExcalidrawViewViewModel | null = useViewModel<ExcalidrawViewViewModel>(
    async () => {
      const rawViewData = await universalStorage.getContext(storageKey)
      const viewData: IExcalidrawViewData = ExcalidrawViewViewModel.normalize(rawViewData)
      return new ExcalidrawViewViewModel({
        mode: mode ?? viewData.mode,
        saveFile: onSaveFile,
      })
    },
  )
  const context: IExcalidrawViewContext | null = React.useMemo<IExcalidrawViewContext | null>(
    () => (viewmodel ? { viewmodel } : null),
    [viewmodel],
  )

  if (!viewmodel || !context) return <React.Fragment />

  return (
    <React.Fragment>
      <ExcalidrawViewContextType.Provider value={context}>
        {children}
      </ExcalidrawViewContextType.Provider>
      <SideEffect
        viewmodel={viewmodel}
        content={content}
        contentError={contentError}
        mode={mode}
        storageKey={storageKey}
      />
    </React.Fragment>
  )
}

ExcalidrawViewProvider.displayName = 'ExcalidrawViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectProps {
  readonly viewmodel: ExcalidrawViewViewModel
  readonly content: string | null
  readonly contentError: string | null
  readonly mode?: ModeEnum
  readonly storageKey: string
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, content, contentError, mode, storageKey } = props

  usePersistAsync(viewmodel, storageKey, [viewmodel.mode$])
  useSyncProps(viewmodel, mode)
  useData(viewmodel, content, contentError)

  return <React.Fragment />
}

SideEffect.displayName = 'ExcalidrawViewSideEffect'

// /////////////////////////////////////////////////////////////////////////////////////////////////

const useSyncProps = (viewmodel: ExcalidrawViewViewModel, mode: ModeEnum | undefined): void => {
  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.mode$.next(mode ?? viewmodel.mode$.getSnapshot())
  }, [viewmodel, mode])
}

const useData = (
  viewmodel: ExcalidrawViewViewModel,
  content: string | null,
  contentError: string | null,
): void => {
  React.useEffect(() => {
    if (viewmodel.disposed) return

    if (contentError) {
      viewmodel.content$.next(null)
      toast.error(typeof contentError === 'string' ? contentError : String(contentError))
    } else {
      viewmodel.content$.next(content)
    }
  }, [content, contentError, viewmodel])
}
