import React from 'react'
import { JsonViewContextType } from './context'
import type { ModeEnum } from './types'
import { JsonViewViewModel } from './viewmodel'

interface IProps {
  readonly mode?: ModeEnum
  readonly content?: string | null
  readonly children: React.ReactNode
}

export const JsonViewProvider: React.FC<IProps> = props => {
  const { mode, content, children } = props
  const [viewmodel] = React.useState<JsonViewViewModel>(
    () => new JsonViewViewModel({ mode, content }),
  )
  const value = React.useMemo(() => ({ viewmodel }), [viewmodel])

  return (
    <JsonViewContextType.Provider value={value}>
      {children}
      <SideEffect viewmodel={viewmodel} mode={mode} content={content} />
    </JsonViewContextType.Provider>
  )
}

JsonViewProvider.displayName = 'JsonViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectProps {
  readonly viewmodel: JsonViewViewModel
  readonly mode?: ModeEnum
  readonly content?: string | null
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, mode, content } = props

  React.useEffect(() => {
    viewmodel.mode$.next(mode ?? 1)
  }, [viewmodel.mode$, mode])

  React.useEffect(() => {
    viewmodel.content$.next(content ?? null)
  }, [viewmodel.content$, content])

  return <React.Fragment />
}

SideEffect.displayName = 'JsonViewSideEffect'
