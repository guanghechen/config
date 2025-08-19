import { Computed } from '@guanghechen/react-viewmodel'
import React from 'react'
import type { IMarkdownFileData } from '@/hook/api/file'
import { useFileResult } from '@/hook/useFileResult'
import { useSingleton } from '@/hook/useSingleton'
import type { IMarkdownViewContext } from './context'
import { MarkdownViewContextType } from './context'
import type { IMarkdownViewData, ModeEnum } from './types'
import { MarkdownViewViewModel } from './viewmodel'

const storageKey: string = '#/view/filetype/markdown'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string | null
  readonly filepathDirtyTick: number
  readonly tocActivatedIdentifier?: string | null
  readonly specifiedTocActivatedIdentifier?: string | null
  readonly mode?: ModeEnum
  readonly children: React.ReactNode
}

export const MarkdownViewProvider: React.FC<IProps> = props => {
  const {
    workspace,
    filepath,
    filepathDirtyTick,
    tocActivatedIdentifier,
    specifiedTocActivatedIdentifier,
    mode,
    children,
  } = props
  const viewmodel: MarkdownViewViewModel | null = useSingleton<MarkdownViewViewModel>(() => {
    const initialData: Partial<IMarkdownViewData> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )
    return MarkdownViewViewModel.fromData({
      mode: mode ?? initialData.mode,
    })
  })
  const context: IMarkdownViewContext | null = React.useMemo<IMarkdownViewContext | null>(
    () => (viewmodel ? { viewmodel } : null),
    [viewmodel],
  )

  if (!viewmodel || !context) return <React.Fragment />

  return (
    <React.Fragment>
      <MarkdownViewContextType.Provider value={context}>
        {children}
      </MarkdownViewContextType.Provider>
      <SideEffect
        viewmodel={viewmodel}
        workspace={workspace}
        filepath={filepath}
        filepathDirtyTick={filepathDirtyTick}
        tocActivatedIdentifier={tocActivatedIdentifier}
        specifiedTocActivatedIdentifier={specifiedTocActivatedIdentifier}
        mode={mode}
      />
    </React.Fragment>
  )
}

MarkdownViewProvider.displayName = 'MarkdownViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectProps {
  readonly viewmodel: MarkdownViewViewModel
  readonly workspace: string | null
  readonly filepath: string | null
  readonly filepathDirtyTick: number
  readonly tocActivatedIdentifier?: string | null
  readonly specifiedTocActivatedIdentifier?: string | null
  readonly mode?: ModeEnum
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const {
    viewmodel,
    workspace,
    filepath,
    filepathDirtyTick,
    tocActivatedIdentifier,
    specifiedTocActivatedIdentifier,
    mode,
  } = props

  const { data, error } = useFileResult<IMarkdownFileData>(workspace, filepath, filepathDirtyTick)

  React.useEffect(() => {
    if (viewmodel.disposed) return

    if (data) {
      viewmodel.data$.next(data)
      viewmodel.contentError$.next(null)
    } else if (error) {
      viewmodel.data$.next(null)
      viewmodel.contentError$.next(typeof error === 'string' ? error : String(error))
    } else {
      viewmodel.data$.next(null)
      viewmodel.contentError$.next(null)
    }
  }, [data, error, viewmodel])

  React.useEffect(() => {
    const computed = Computed.fromObservables([viewmodel.mode$], () => {
      const data: IMarkdownViewData = viewmodel.dump()
      window.localStorage.setItem(storageKey, JSON.stringify(data))
    })
    return (): void => {
      computed.dispose()
    }
  }, [viewmodel])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.filepath$.next(filepath ?? null)
  }, [viewmodel, filepath])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.tocActivatedIdentifier$.next(tocActivatedIdentifier ?? null)
  }, [viewmodel, tocActivatedIdentifier])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.specifiedTocActivatedIdentifier$.next(specifiedTocActivatedIdentifier ?? null)
  }, [viewmodel, specifiedTocActivatedIdentifier])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.mode$.next(mode ?? viewmodel.mode$.getSnapshot())
  }, [viewmodel, mode])

  return <React.Fragment />
}

SideEffect.displayName = 'MarkdownViewSideEffect'
