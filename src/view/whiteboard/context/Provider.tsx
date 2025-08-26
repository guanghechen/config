import { Computed } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useSingleton } from '@/hook/useSingleton'
import type { IWhiteboardViewContext } from './context'
import { WhiteboardViewContextType } from './context'
import type { IWhiteboardViewData } from './types'
import { WhiteboardViewViewModel } from './viewmodel'

const storageKey: string = '#/view/whiteboard'

interface IProps {
  readonly content?: string | null
  readonly filetype?: string
  readonly children: React.ReactNode
}

export const WhiteboardViewProvider: React.FC<IProps> = ({ content, filetype, children }) => {
  const viewmodel: WhiteboardViewViewModel | null = useSingleton<WhiteboardViewViewModel>(() => {
    const rawViewData: Partial<IWhiteboardViewData> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )

    const viewData: IWhiteboardViewData = WhiteboardViewViewModel.normalize(rawViewData)
    return new WhiteboardViewViewModel({
      content: content ?? viewData.content,
      filetype: filetype ?? viewData.filetype,
    })
  })

  const context: IWhiteboardViewContext | null = React.useMemo<IWhiteboardViewContext | null>(
    () => (viewmodel ? { viewmodel } : null),
    [viewmodel],
  )

  if (!viewmodel || !context) return <React.Fragment />

  return (
    <React.Fragment>
      <WhiteboardViewContextType.Provider value={context}>
        {children}
      </WhiteboardViewContextType.Provider>
      <SideEffect viewmodel={viewmodel} />
    </React.Fragment>
  )
}

WhiteboardViewProvider.displayName = 'WhiteboardViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectProps {
  readonly viewmodel: WhiteboardViewViewModel
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel } = props

  usePersistent(viewmodel)

  return <React.Fragment />
}

SideEffect.displayName = 'WhiteboardViewSideEffect'

// /////////////////////////////////////////////////////////////////////////////////////////////////

const usePersistent = (viewmodel: WhiteboardViewViewModel): void => {
  React.useEffect(() => {
    const computed = Computed.fromObservables([viewmodel.content$, viewmodel.filetype$], () => {
      const data: IWhiteboardViewData = viewmodel.dump()
      window.localStorage.setItem(storageKey, JSON.stringify(data))
    })
    return (): void => {
      computed.dispose()
    }
  }, [viewmodel])
}
