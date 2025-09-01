import React from 'react'
import { usePersist } from '@/hook/usePersist'
import { useViewModel } from '@/hook/useViewModel'
import type { IUnknownViewContext } from './context'
import { UnknownViewContextType } from './context'
import type { IUnknownViewData, ModeEnum } from './types'
import { UnknownViewViewModel } from './viewmodel'

interface IProps {
  readonly placeholder?: boolean
  readonly mode?: ModeEnum
  readonly storageKeyScope: string
  readonly children: React.ReactNode
}

export const UnknownViewProvider: React.FC<IProps> = props => {
  const { placeholder, mode, storageKeyScope, children } = props
  const storageKey = `${storageKeyScope}/filetype/unknown`
  const viewmodel: UnknownViewViewModel | null = useViewModel<UnknownViewViewModel>(() => {
    const rawViewData: Partial<IUnknownViewData> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )
    const viewData: IUnknownViewData = UnknownViewViewModel.normalize(
      { mode: mode ?? 1 }, // DEFAULT_DATA equivalent
      rawViewData,
    )
    return new UnknownViewViewModel({
      mode: mode ?? viewData.mode,
      placeholder,
    })
  })
  const context: IUnknownViewContext | null = React.useMemo<IUnknownViewContext | null>(
    () => (viewmodel ? { viewmodel } : null),
    [viewmodel],
  )

  if (!viewmodel || !context) return <React.Fragment />

  return (
    <React.Fragment>
      <UnknownViewContextType.Provider value={context}>{children}</UnknownViewContextType.Provider>
      <SideEffect
        viewmodel={viewmodel}
        placeholder={placeholder}
        mode={mode}
        storageKey={storageKey}
      />
    </React.Fragment>
  )
}

UnknownViewProvider.displayName = 'UnknownViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectProps {
  readonly viewmodel: UnknownViewViewModel
  readonly placeholder?: boolean
  readonly mode?: ModeEnum
  readonly storageKey: string
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, placeholder, mode, storageKey } = props

  usePersist(viewmodel, storageKey, [viewmodel.mode$])
  useSyncProps(viewmodel, placeholder, mode)

  return <React.Fragment />
}

SideEffect.displayName = 'UnknownViewSideEffect'

// /////////////////////////////////////////////////////////////////////////////////////////////////

const useSyncProps = (
  viewmodel: UnknownViewViewModel,
  placeholder: boolean | undefined,
  mode: ModeEnum | undefined,
): void => {
  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.placeholder$.next(placeholder ?? true)
  }, [viewmodel, placeholder])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.mode$.next(mode ?? viewmodel.mode$.getSnapshot())
  }, [viewmodel, mode])
}
