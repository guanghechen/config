import { Computed } from '@guanghechen/react-viewmodel'
import React from 'react'
import { toast } from 'react-toastify'
import { useSingleton } from '@/hook/useSingleton'
import type { IMarkdownFileData } from '@/shared/types/api'
import type { IMarkdownViewContext } from './context'
import { MarkdownViewContextType } from './context'
import type { IMarkdownViewData, ModeEnum } from './types'
import { MarkdownViewViewModel } from './viewmodel'

interface IProps {
  readonly data: IMarkdownFileData | null
  readonly dataError: string | null
  readonly mode?: ModeEnum
  readonly storageKeyScope: string
  readonly children: React.ReactNode
}

export const MarkdownViewProvider: React.FC<IProps> = props => {
  const { data, dataError, mode, storageKeyScope, children } = props
  const storageKey = `${storageKeyScope}/filetype/markdown`
  const viewmodel: MarkdownViewViewModel | null = useSingleton<MarkdownViewViewModel>(() => {
    const rawViewData: Partial<IMarkdownViewData> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )
    const viewData: IMarkdownViewData = MarkdownViewViewModel.normalize(rawViewData)
    return new MarkdownViewViewModel({
      mode: mode ?? viewData.mode,
    })
  })
  const context: IMarkdownViewContext | null = React.useMemo<IMarkdownViewContext | null>(
    () => (viewmodel ? { viewmodel } : null),
    [viewmodel],
  )

  if (!viewmodel || !context) return <React.Fragment />

  return (
    <React.Fragment>
      <MarkdownViewContextType.Provider value={context}>
        {children}
      </MarkdownViewContextType.Provider>
      <SideEffect
        viewmodel={viewmodel}
        data={data}
        dataError={dataError}
        mode={mode}
        storageKey={storageKey}
      />
    </React.Fragment>
  )
}

MarkdownViewProvider.displayName = 'MarkdownViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectProps {
  readonly viewmodel: MarkdownViewViewModel
  readonly data: IMarkdownFileData | null
  readonly dataError: string | null
  readonly mode?: ModeEnum
  readonly storageKey: string
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, data, dataError, mode, storageKey } = props

  usePersistent(viewmodel, storageKey)
  useSyncProps(viewmodel, mode)
  useData(viewmodel, data, dataError)

  return <React.Fragment />
}

SideEffect.displayName = 'MarkdownViewSideEffect'

// /////////////////////////////////////////////////////////////////////////////////////////////////

const usePersistent = (viewmodel: MarkdownViewViewModel, storageKey: string): void => {
  React.useEffect(() => {
    const computed = Computed.fromObservables([viewmodel.mode$], () => {
      const data: IMarkdownViewData = viewmodel.dump()
      window.localStorage.setItem(storageKey, JSON.stringify(data))
    })
    return (): void => {
      computed.dispose()
    }
  }, [viewmodel, storageKey])
}

const useSyncProps = (viewmodel: MarkdownViewViewModel, mode: ModeEnum | undefined): void => {
  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.mode$.next(mode ?? viewmodel.mode$.getSnapshot())
  }, [viewmodel, mode])
}

const useData = (
  viewmodel: MarkdownViewViewModel,
  data: IMarkdownFileData | null,
  dataError: string | null,
): void => {
  React.useEffect(() => {
    if (viewmodel.disposed) return

    if (dataError) {
      viewmodel.data$.next(null)
      toast.error(typeof dataError === 'string' ? dataError : String(dataError))
    } else {
      viewmodel.data$.next(data)
    }
  }, [data, dataError, viewmodel])
}
