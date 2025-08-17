import { Computed, useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import type { ITextFileData } from '@/hook/api/file'
import { useFileResult } from '@/hook/useFileResult'
import { useSingleton } from '@/hook/useSingleton'
import { validateTransformerData } from '@/shared/transform/util'
import { transformTextToNodes } from '../util/transform'
import type { ITextViewContext } from './context'
import { TextViewContextType } from './context'
import type { ITextViewData, ModeEnum, ViewModeEnum } from './types'
import { TextViewViewModel } from './viewmodel'

const storageKey: string = '#/view/filetype/text'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string | null
  readonly filepathDirtyTick: number
  readonly mode?: ModeEnum
  readonly viewMode?: ViewModeEnum
  readonly children: React.ReactNode
}

export const TextViewProvider: React.FC<IProps> = props => {
  const { workspace, filepath, filepathDirtyTick, mode, viewMode, children } = props
  const viewmodel: TextViewViewModel | null = useSingleton<TextViewViewModel>(() => {
    const initialData: Partial<ITextViewData> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )
    return TextViewViewModel.fromData({
      mode: mode ?? initialData.mode,
      viewMode: viewMode ?? initialData.viewMode,
      transformConfig: validateTransformerData(initialData.transformConfig)
        ? initialData.transformConfig
        : undefined,
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
        workspace={workspace}
        filepath={filepath}
        filepathDirtyTick={filepathDirtyTick}
        mode={mode}
        viewMode={viewMode}
      />
    </React.Fragment>
  )
}

TextViewProvider.displayName = 'TextViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectProps {
  readonly viewmodel: TextViewViewModel
  readonly workspace: string | null
  readonly filepath: string | null
  readonly filepathDirtyTick: number
  readonly mode?: ModeEnum
  readonly viewMode?: ViewModeEnum
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, workspace, filepath, filepathDirtyTick, mode, viewMode } = props
  const content: string | null = useStateValue<string | null>(viewmodel.content$)
  const { data, error } = useFileResult<ITextFileData>(workspace, filepath, filepathDirtyTick)

  React.useEffect(() => {
    if (viewmodel.disposed) return

    if (data) {
      viewmodel.content$.next(data.content)
      viewmodel.error$.next(null)
    } else if (error) {
      viewmodel.content$.next(null)
      viewmodel.error$.next(typeof error === 'string' ? error : String(error))
    } else {
      viewmodel.content$.next(null)
      viewmodel.error$.next(null)
    }
  }, [data, error, viewmodel])

  React.useEffect(() => {
    const computed = Computed.fromObservables(
      [viewmodel.mode$, viewmodel.viewMode$, viewmodel.transformConfig$],
      () => {
        const data: ITextViewData = viewmodel.dump()
        window.localStorage.setItem(storageKey, JSON.stringify(data))
      },
    )
    return (): void => {
      computed.dispose()
    }
  }, [viewmodel])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.workspace$.next(workspace ?? null)
  }, [viewmodel, workspace])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.filepath$.next(filepath ?? null)
  }, [viewmodel, filepath])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.mode$.next(mode ?? viewmodel.mode$.getSnapshot())
  }, [viewmodel, mode])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.viewMode$.next(viewMode ?? viewmodel.viewMode$.getSnapshot())
  }, [viewmodel, viewMode])

  React.useEffect(() => {
    if (viewmodel.disposed) return

    const transformConfig = viewmodel.transformConfig$.getSnapshot()
    if (content && validateTransformerData(transformConfig)) {
      const result = transformTextToNodes(content as string, transformConfig)
      if (result.error) {
        viewmodel.transformedNodes$.next([])
      } else {
        viewmodel.transformedNodes$.next(result.nodes)
      }
    }
  }, [viewmodel, content]) // Re-run when content or transform config changes

  return <React.Fragment />
}

SideEffect.displayName = 'TextViewSideEffect'
