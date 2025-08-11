import { Computed } from '@guanghechen/react-viewmodel'
import React from 'react'
import { JsonViewContextType } from './context'
import type { IJsonViewData, ModeEnum } from './types'
import { JsonViewViewModel } from './viewmodel'

const storageKey: string = '@guanghechen/yozora/json-view'

interface IProps {
  readonly mode?: ModeEnum
  readonly content?: string | null
  readonly children: React.ReactNode
}

export const JsonViewProvider: React.FC<IProps> = props => {
  const { mode, content, children } = props
  const [viewmodel] = React.useState<JsonViewViewModel>(() => {
    const initialData: Partial<IJsonViewData> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )
    return JsonViewViewModel.fromData({
      mode: mode ?? initialData.mode,
    })
  })
  const value = React.useMemo(() => ({ viewmodel }), [viewmodel])

  return (
    <React.Fragment>
      <JsonViewContextType.Provider value={value}>{children}</JsonViewContextType.Provider>
      <SideEffect viewmodel={viewmodel} mode={mode} content={content} />
    </React.Fragment>
  )
}

JsonViewProvider.displayName = 'JsonViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectPropsWithMode {
  readonly viewmodel: JsonViewViewModel
  readonly mode?: ModeEnum
  readonly content?: string | null
}

const SideEffect: React.FC<ISideEffectPropsWithMode> = props => {
  const { viewmodel, mode, content } = props

  React.useEffect(() => {
    const computed = Computed.fromObservables([viewmodel.mode$], () => {
      const data: IJsonViewData = viewmodel.dump()
      window.localStorage.setItem(storageKey, JSON.stringify(data))
    })
    return (): void => {
      computed.dispose()
    }
  }, [viewmodel])

  React.useEffect(() => {
    viewmodel.mode$.next(mode ?? 1)
  }, [viewmodel.mode$, mode])

  React.useEffect(() => {
    viewmodel.content$.next(content ?? null)
  }, [viewmodel.content$, content])

  return <React.Fragment />
}

SideEffect.displayName = 'JsonViewSideEffect'
