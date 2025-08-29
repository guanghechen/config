import { useViewModel } from '@guanghechen/react-viewmodel'
import React from 'react'
import { usePersist } from '@/hook/usePersist'
import type { IWhiteboardViewContext } from './context'
import { WhiteboardViewContextType } from './context'
import type { IWhiteboardViewData } from './types'
import { WhiteboardViewViewModel } from './viewmodel'

const storageKey: string = '#/view/whiteboard'

interface IProps {
  readonly content?: string | null
  readonly filetype?: string
  readonly editorVisible?: boolean
  readonly editorWidth?: number
  readonly editorLanguage?: string
  readonly filepath?: string | null
  readonly children: React.ReactNode
}

export const WhiteboardViewProvider: React.FC<IProps> = ({
  content,
  filetype,
  editorVisible,
  editorWidth,
  editorLanguage,
  filepath,
  children,
}) => {
  const viewmodel: WhiteboardViewViewModel | null = useViewModel<WhiteboardViewViewModel>(() => {
    const rawViewData: Partial<IWhiteboardViewData> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )

    const viewData: IWhiteboardViewData = WhiteboardViewViewModel.normalize(rawViewData)
    return new WhiteboardViewViewModel({
      content: content ?? viewData.content,
      filetype: filetype ?? viewData.filetype,
      editorVisible: editorVisible ?? viewData.editorVisible,
      editorWidth: editorWidth ?? viewData.editorWidth,
      editorLanguage: editorLanguage ?? viewData.editorLanguage,
      filepath: filepath ?? viewData.filepath,
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

  usePersist(viewmodel, storageKey, [
    viewmodel.content$,
    viewmodel.filetype$,
    viewmodel.editorVisible$,
    viewmodel.editorWidth$,
    viewmodel.editorLanguage$,
    viewmodel.filepath$,
  ])

  return <React.Fragment />
}

SideEffect.displayName = 'WhiteboardViewSideEffect'

// /////////////////////////////////////////////////////////////////////////////////////////////////
