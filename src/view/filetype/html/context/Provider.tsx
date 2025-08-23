import { Computed } from '@guanghechen/react-viewmodel'
import React from 'react'
import { toast } from 'react-toastify'
import { useSingleton } from '@/hook/useSingleton'
import type { IHtmlViewContext } from './context'
import { HtmlViewContextType } from './context'
import type { IHtmlViewData, ModeEnum } from './types'
import { HtmlViewViewModel } from './viewmodel'

const storageKey: string = '#/view/filetype/html'

interface IProps {
  readonly content: string | null
  readonly contentError: string | null
  readonly mode?: ModeEnum
  readonly enableTailwindcss?: boolean
  readonly children: React.ReactNode
}

export const HtmlViewProvider: React.FC<IProps> = props => {
  const { content, contentError, mode, enableTailwindcss, children } = props
  const viewmodel: HtmlViewViewModel | null = useSingleton<HtmlViewViewModel>(() => {
    const rawViewData: Partial<IHtmlViewData> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )
    const viewData: IHtmlViewData = HtmlViewViewModel.normalize(rawViewData)
    return new HtmlViewViewModel({
      mode: mode ?? viewData.mode,
      enableTailwindcss: enableTailwindcss ?? viewData.enableTailwindcss,
    })
  })
  const context: IHtmlViewContext | null = React.useMemo<IHtmlViewContext | null>(
    () => (viewmodel ? { viewmodel } : null),
    [viewmodel],
  )

  if (!viewmodel || !context) return <React.Fragment />

  return (
    <React.Fragment>
      <HtmlViewContextType.Provider value={context}>{children}</HtmlViewContextType.Provider>
      <SideEffect
        viewmodel={viewmodel}
        content={content}
        contentError={contentError}
        mode={mode}
        enableTailwindcss={enableTailwindcss}
      />
    </React.Fragment>
  )
}

HtmlViewProvider.displayName = 'HtmlViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectProps {
  readonly viewmodel: HtmlViewViewModel
  readonly content: string | null
  readonly contentError: string | null
  readonly mode?: ModeEnum
  readonly enableTailwindcss?: boolean
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, content, contentError, mode, enableTailwindcss } = props

  usePersistent(viewmodel)
  useSyncProps(viewmodel, mode, enableTailwindcss)
  useData(viewmodel, content, contentError)

  return <React.Fragment />
}

SideEffect.displayName = 'HtmlViewSideEffect'

// /////////////////////////////////////////////////////////////////////////////////////////////////

const usePersistent = (viewmodel: HtmlViewViewModel): void => {
  React.useEffect(() => {
    const computed = Computed.fromObservables(
      [viewmodel.mode$, viewmodel.enableTailwindcss$],
      () => {
        const data: IHtmlViewData = viewmodel.dump()
        window.localStorage.setItem(storageKey, JSON.stringify(data))
      },
    )
    return (): void => {
      computed.dispose()
    }
  }, [viewmodel])
}

const useSyncProps = (
  viewmodel: HtmlViewViewModel,
  mode: ModeEnum | undefined,
  enableTailwindcss: boolean | undefined,
): void => {
  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.mode$.next(mode ?? viewmodel.mode$.getSnapshot())
  }, [viewmodel, mode])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.enableTailwindcss$.next(
      enableTailwindcss ?? viewmodel.enableTailwindcss$.getSnapshot(),
    )
  }, [viewmodel, enableTailwindcss])
}

const useData = (
  viewmodel: HtmlViewViewModel,
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
