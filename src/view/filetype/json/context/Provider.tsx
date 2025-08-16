import { Computed } from '@guanghechen/react-viewmodel'
import JSON5 from 'json5'
import React from 'react'
import type { IJsonFileData } from '@/hook/api/file'
import { useFileResult } from '@/hook/useFileResult'
import { useSingleton } from '@/hook/useSingleton'
import type { IJsonViewContext } from './context'
import { JsonViewContextType } from './context'
import type { IJsonViewData, ModeEnum } from './types'
import { JsonViewViewModel } from './viewmodel'

const storageKey: string = '#/view/filetype/json'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string | null
  readonly filepathDirtyTick: number
  readonly mode?: ModeEnum
  readonly content?: string | null
  readonly children: React.ReactNode
}

export const JsonViewProvider: React.FC<IProps> = props => {
  const { workspace, filepath, filepathDirtyTick, mode, content, children } = props
  const viewmodel: JsonViewViewModel | null = useSingleton<JsonViewViewModel>(() => {
    const initialData: Partial<IJsonViewData> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )
    return JsonViewViewModel.fromData({
      mode: mode ?? initialData.mode,
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
        workspace={workspace}
        filepath={filepath}
        filepathDirtyTick={filepathDirtyTick}
        mode={mode}
        content={content}
      />
    </React.Fragment>
  )
}

JsonViewProvider.displayName = 'JsonViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectPropsWithMode {
  readonly viewmodel: JsonViewViewModel
  readonly workspace: string | null
  readonly filepath: string | null
  readonly filepathDirtyTick: number
  readonly mode?: ModeEnum
  readonly content?: string | null
}

const SideEffect: React.FC<ISideEffectPropsWithMode> = props => {
  const { viewmodel, workspace, filepath, filepathDirtyTick, mode, content } = props

  const { data, error } = useFileResult<IJsonFileData>(workspace, filepath, filepathDirtyTick)

  React.useEffect(() => {
    if (viewmodel.disposed) return

    if (data?.content) {
      viewmodel.content$.next(data.content)

      // Parse JSON content
      try {
        const parsedJson = JSON5.parse(data.content)
        viewmodel.json$.next(parsedJson)
      } catch (_parseError) {
        viewmodel.json$.next(null)
      }
    } else if (error) {
      viewmodel.content$.next(null)
      viewmodel.json$.next(null)
    } else {
      viewmodel.content$.next(content ?? null)
      if (content) {
        try {
          const parsedJson = JSON5.parse(content)
          viewmodel.json$.next(parsedJson)
        } catch (_parseError) {
          viewmodel.json$.next(null)
        }
      } else {
        viewmodel.json$.next(null)
      }
    }
  }, [data, error, content, viewmodel])

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
    if (viewmodel.disposed) return
    viewmodel.mode$.next(mode ?? 1)
  }, [viewmodel, mode])

  return <React.Fragment />
}

SideEffect.displayName = 'JsonViewSideEffect'
