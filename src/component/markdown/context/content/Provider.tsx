import type { Root } from '@yozora/ast'
import React from 'react'
import { useSingleton } from '@/hook/useSingleton'
import { useMarkdownTopViewmodel } from '../top'
import type { IMarkdownContentContext } from './context'
import { MarkdownContentContextType } from './context'
import { MarkdownContentViewModel } from './viewmodel'

interface IProps {
  /**
   * Text content of markdown.
   */
  readonly ast: Root
  /**
   * Children component.
   */
  readonly children?: React.ReactNode
}

export const MarkdownContentProvider: React.FC<IProps> = props => {
  const { ast } = props
  const top = useMarkdownTopViewmodel()

  const viewmodel: MarkdownContentViewModel | null = useSingleton<MarkdownContentViewModel>(() => {
    return new MarkdownContentViewModel({ ast, top })
  })

  const context: IMarkdownContentContext | null = React.useMemo<IMarkdownContentContext | null>(
    () => (viewmodel ? { viewmodel } : null),
    [viewmodel],
  )

  if (!viewmodel || !context) return <React.Fragment />

  return (
    <React.Fragment>
      <MarkdownContentContextType.Provider value={context}>
        {props.children}
      </MarkdownContentContextType.Provider>
      <SideEffect viewmodel={viewmodel} ast={ast} />
    </React.Fragment>
  )
}
MarkdownContentProvider.displayName = 'MarkdownContentProvider'

interface ISideEffectProps {
  readonly viewmodel: MarkdownContentViewModel
  readonly ast: Root
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, ast } = props

  React.useEffect(() => {
    viewmodel.ast$.next(ast)
  }, [viewmodel, ast])

  return <React.Fragment />
}
