import { useStateValue, useViewModel } from '@guanghechen/react-viewmodel'
import React from 'react'
import { toast } from 'react-toastify'
import { usePersistAsync } from '@/hook/usePersistAsync'
import type { ITextTransformConfig } from '@/shared/types'
import { validateTransformConfig } from '@/shared/util'
import { universalStorage } from '@/util/storage'
import { transformTextToNodes } from '../util/transform'
import type { ITextViewContext } from './context'
import { TextViewContextType } from './context'
import type { ContentModeEnum, ITextViewData, ModeEnum } from './types'
import { TextViewViewModel } from './viewmodel'

interface IProps {
  readonly content: string | null
  readonly contentError: string | null
  readonly mode?: ModeEnum
  readonly contentMode?: ContentModeEnum
  readonly storageKeyScope: string
  readonly children: React.ReactNode
}

export const TextViewProvider: React.FC<IProps> = props => {
  const { content, contentError, mode, contentMode, storageKeyScope, children } = props
  const storageKey = `${storageKeyScope}/filetype/text`
  const viewmodel: TextViewViewModel | null = useViewModel<TextViewViewModel>(async () => {
    const rawViewData = await universalStorage.getContext<Partial<ITextViewData>>(storageKey)
    const viewData: ITextViewData = TextViewViewModel.normalize(rawViewData)

    return new TextViewViewModel({
      mode: mode ?? viewData.mode,
      contentMode: contentMode ?? viewData.contentMode,
      nodeDetailsPaneWidth: viewData.nodeDetailsPaneWidth,
      transformConfig: viewData.transformConfig,
    })
  })
  const context: ITextViewContext | null = React.useMemo<ITextViewContext | null>(
    () => (viewmodel ? { viewmodel } : null),
    [viewmodel],
  )

  if (!viewmodel || !context) return <React.Fragment />

  return (
    <React.Fragment>
      <TextViewContextType.Provider value={context}>{children}</TextViewContextType.Provider>
      <SideEffect
        viewmodel={viewmodel}
        content={content}
        contentError={contentError}
        mode={mode}
        contentMode={contentMode}
        storageKey={storageKey}
      />
    </React.Fragment>
  )
}

TextViewProvider.displayName = 'TextViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectProps {
  readonly viewmodel: TextViewViewModel
  readonly content: string | null
  readonly contentError: string | null
  readonly mode?: ModeEnum
  readonly contentMode?: ContentModeEnum
  readonly storageKey: string
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, content, contentError, mode, contentMode, storageKey } = props

  usePersistAsync(viewmodel, storageKey, [
    viewmodel.mode$,
    viewmodel.contentMode$,
    viewmodel.nodeDetailsPaneWidth$,
    viewmodel.transformConfig$,
  ])
  useSyncProps(viewmodel, mode, contentMode)
  useData(viewmodel, content, contentError)
  useAutoTransform(viewmodel)

  return <React.Fragment />
}

SideEffect.displayName = 'TextViewSideEffect'

// /////////////////////////////////////////////////////////////////////////////////////////////////

const useSyncProps = (
  viewmodel: TextViewViewModel,
  mode: ModeEnum | undefined,
  contentMode: ContentModeEnum | undefined,
): void => {
  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.mode$.next(mode ?? viewmodel.mode$.getSnapshot())
  }, [viewmodel, mode])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.contentMode$.next(contentMode ?? viewmodel.contentMode$.getSnapshot())
  }, [viewmodel, contentMode])
}

const useData = (
  viewmodel: TextViewViewModel,
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

const useAutoTransform = (viewmodel: TextViewViewModel): void => {
  const content: string | null = useStateValue<string | null>(viewmodel.content$)

  React.useEffect(() => {
    if (viewmodel.disposed || !content) return

    const transformConfig: ITextTransformConfig = viewmodel.transformConfig$.getSnapshot()
    if (validateTransformConfig(transformConfig)) {
      const result = transformTextToNodes(content as string, transformConfig)
      if (result.error) {
        viewmodel.records$.next([])
      } else {
        viewmodel.records$.next(result.nodes)
      }
    }
  }, [viewmodel, content])
}
