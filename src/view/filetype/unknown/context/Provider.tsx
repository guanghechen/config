import { Computed } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useSingleton } from '@/hook/useSingleton'
import type { IUnknownViewContext } from './context'
import { UnknownViewContextType } from './context'
import type { IUnknownViewData, ModeEnum } from './types'
import { UnknownViewViewModel } from './viewmodel'

const storageKey: string = '#/view/filetype/unknown'

interface IProps {
  readonly placeholder?: boolean
  readonly mode?: ModeEnum
  readonly children: React.ReactNode
}

export const UnknownViewProvider: React.FC<IProps> = props => {
  const { placeholder, mode, children } = props
  const viewmodel: UnknownViewViewModel | null = useSingleton<UnknownViewViewModel>(() => {
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
      <SideEffect viewmodel={viewmodel} placeholder={placeholder} mode={mode} />
    </React.Fragment>
  )
}

UnknownViewProvider.displayName = 'UnknownViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectProps {
  readonly viewmodel: UnknownViewViewModel
  readonly placeholder?: boolean
  readonly mode?: ModeEnum
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, placeholder, mode } = props

  usePersistent(viewmodel)
  useSyncProps(viewmodel, placeholder, mode)

  return <React.Fragment />
}

SideEffect.displayName = 'UnknownViewSideEffect'

// /////////////////////////////////////////////////////////////////////////////////////////////////

const usePersistent = (viewmodel: UnknownViewViewModel): void => {
  React.useEffect(() => {
    const computed = Computed.fromObservables([viewmodel.mode$], () => {
      const data: IUnknownViewData = viewmodel.dump()
      window.localStorage.setItem(storageKey, JSON.stringify(data))
    })
    return (): void => {
      computed.dispose()
    }
  }, [viewmodel])
}

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
