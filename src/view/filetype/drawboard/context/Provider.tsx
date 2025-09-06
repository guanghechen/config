import { useViewModel } from '@guanghechen/react-viewmodel'
import React from 'react'
import { toast } from 'react-toastify'
import { usePersistAsync } from '@/hook/usePersistAsync'
import { universalStorage } from '@/util/storage'
import type { IDrawboardViewContext } from './context'
import { DrawboardViewContextType } from './context'
import type { IDrawboardViewData, ModeEnum } from './types'
import { DrawboardViewViewModel } from './viewmodel'

interface IProps {
  readonly content: string | null
  readonly contentError: string | null
  readonly onSaveFile?: (content: string) => void
  readonly mode?: ModeEnum
  readonly storageKeyScope: string
  readonly children: React.ReactNode
}

export const DrawboardViewProvider: React.FC<IProps> = props => {
  const { content, contentError, onSaveFile, mode, storageKeyScope, children } = props
  const storageKey = `${storageKeyScope}/filetype/drawboard`
  const viewmodel: DrawboardViewViewModel | null = useViewModel<DrawboardViewViewModel>(
    async () => {
      const rawViewData = await universalStorage.getContext(storageKey)
      const viewData: IDrawboardViewData = DrawboardViewViewModel.normalize(rawViewData)
      return new DrawboardViewViewModel({
        mode: mode ?? viewData.mode,
        saveFile: onSaveFile,
      })
    },
  )
  const context: IDrawboardViewContext | null = React.useMemo<IDrawboardViewContext | null>(
    () => (viewmodel ? { viewmodel } : null),
    [viewmodel],
  )

  if (!viewmodel || !context) return <React.Fragment />

  return (
    <React.Fragment>
      <DrawboardViewContextType.Provider value={context}>
        {children}
      </DrawboardViewContextType.Provider>
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

DrawboardViewProvider.displayName = 'DrawboardViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectProps {
  readonly viewmodel: DrawboardViewViewModel
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

SideEffect.displayName = 'DrawboardViewSideEffect'

// /////////////////////////////////////////////////////////////////////////////////////////////////

const useSyncProps = (viewmodel: DrawboardViewViewModel, mode: ModeEnum | undefined): void => {
  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.mode$.next(mode ?? viewmodel.mode$.getSnapshot())
  }, [viewmodel, mode])
}

const useData = (
  viewmodel: DrawboardViewViewModel,
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
