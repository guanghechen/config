import { Computed } from '@guanghechen/react-viewmodel'
import JSON5 from 'json5'
import React from 'react'
import { toast } from 'react-toastify'
import { useSingleton } from '@/hook/useSingleton'
import type { IJsonViewContext } from './context'
import { JsonViewContextType } from './context'
import type { IJsonViewData, ModeEnum } from './types'
import { JsonViewViewModel } from './viewmodel'

interface IProps {
  readonly content: string | null
  readonly contentError: string | null
  readonly mode?: ModeEnum
  readonly storageKeyScope: string
  readonly children: React.ReactNode
}

export const JsonViewProvider: React.FC<IProps> = props => {
  const { content, contentError, mode, storageKeyScope, children } = props
  const storageKey = `${storageKeyScope}/filetype/json`
  const viewmodel: JsonViewViewModel | null = useSingleton<JsonViewViewModel>(() => {
    const rawViewData: Partial<IJsonViewData> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )
    const viewData: IJsonViewData = JsonViewViewModel.normalize(rawViewData)
    return new JsonViewViewModel({
      mode: mode ?? viewData.mode,
    })
  })
  const context: IJsonViewContext | null = React.useMemo<IJsonViewContext | null>(
    () => (viewmodel ? { viewmodel } : null),
    [viewmodel],
  )

  if (!viewmodel || !context) return <React.Fragment />

  return (
    <React.Fragment>
      <JsonViewContextType.Provider value={context}>{children}</JsonViewContextType.Provider>
      <SideEffect
        viewmodel={viewmodel}
        content={content}
        contentError={contentError}
        mode={mode}
        storageKey={storageKey}
      />
    </React.Fragment>
  )
}

JsonViewProvider.displayName = 'JsonViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectProps {
  readonly viewmodel: JsonViewViewModel
  readonly content: string | null
  readonly contentError: string | null
  readonly mode?: ModeEnum
  readonly storageKey: string
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, content, contentError, mode, storageKey } = props

  usePersistent(viewmodel, storageKey)
  useSyncProps(viewmodel, mode)
  useData(viewmodel, content, contentError)

  return <React.Fragment />
}

SideEffect.displayName = 'JsonViewSideEffect'

// /////////////////////////////////////////////////////////////////////////////////////////////////

const usePersistent = (viewmodel: JsonViewViewModel, storageKey: string): void => {
  React.useEffect(() => {
    const computed = Computed.fromObservables([viewmodel.mode$], () => {
      const data: IJsonViewData = viewmodel.dump()
      window.localStorage.setItem(storageKey, JSON.stringify(data))
    })
    return (): void => {
      computed.dispose()
    }
  }, [viewmodel, storageKey])
}

const useSyncProps = (viewmodel: JsonViewViewModel, mode: ModeEnum | undefined): void => {
  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.mode$.next(mode ?? viewmodel.mode$.getSnapshot())
  }, [viewmodel, mode])
}

const useData = (
  viewmodel: JsonViewViewModel,
  content: string | null,
  contentError: string | null,
): void => {
  React.useEffect(() => {
    if (viewmodel.disposed) return

    if (contentError) {
      viewmodel.content$.next(null)
      viewmodel.json$.next(null)
      toast.error(typeof contentError === 'string' ? contentError : String(contentError))
    } else if (content) {
      viewmodel.content$.next(content)

      // Parse JSON content
      try {
        const parsedJson = JSON5.parse(content)
        viewmodel.json$.next(parsedJson)
      } catch (_parseError) {
        viewmodel.json$.next(null)
      }
    } else {
      viewmodel.content$.next(null)
      viewmodel.json$.next(null)
    }
  }, [content, contentError, viewmodel])
}
