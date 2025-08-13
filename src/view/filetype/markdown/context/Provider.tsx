import { Computed } from '@guanghechen/react-viewmodel'
import React from 'react'
import { ViewModelCleanupSideEffect } from '@/container/ViewModelCleanup'
import { useFileResult } from '@/hook/useFileResult'
import type { IMarkdownFileData } from '@/util/fetch'
import { MarkdownViewContextType } from './context'
import type { IMarkdownViewData, ModeEnum } from './types'
import { MarkdownViewViewModel } from './viewmodel'

const storageKey: string = '#/view/filetype/markdown'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
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
  const [viewmodel] = React.useState<MarkdownViewViewModel>(() => {
    const initialData: Partial<IMarkdownViewData> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )
    return MarkdownViewViewModel.fromData({
      mode: mode ?? initialData.mode,
    })
  })
  const value = React.useMemo(() => ({ viewmodel }), [viewmodel])

  return (
    <React.Fragment>
      <MarkdownViewContextType.Provider value={value}>{children}</MarkdownViewContextType.Provider>
      <SideEffect
        viewmodel={viewmodel}
        workspace={workspace}
        filepath={filepath}
        filepathDirtyTick={filepathDirtyTick}
        tocActivatedIdentifier={tocActivatedIdentifier}
        specifiedTocActivatedIdentifier={specifiedTocActivatedIdentifier}
        mode={mode}
      />
      <ViewModelCleanupSideEffect viewmodel={viewmodel} />
    </React.Fragment>
  )
}

MarkdownViewProvider.displayName = 'MarkdownViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectProps {
  readonly viewmodel: MarkdownViewViewModel
  readonly workspace: string | null
  readonly filepath: string
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
    if (data) {
      viewmodel.data$.next(data)
      viewmodel.error$.next(null)
    } else if (error) {
      viewmodel.data$.next(null)
      viewmodel.error$.next(typeof error === 'string' ? error : String(error))
    } else {
      viewmodel.data$.next(null)
      viewmodel.error$.next(null)
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
    viewmodel.workspace$.next(workspace)
  }, [viewmodel.workspace$, workspace])

  React.useEffect(() => {
    viewmodel.filepath$.next(filepath)
  }, [viewmodel.filepath$, filepath])

  React.useEffect(() => {
    viewmodel.tocActivatedIdentifier$.next(tocActivatedIdentifier ?? null)
  }, [viewmodel.tocActivatedIdentifier$, tocActivatedIdentifier])

  React.useEffect(() => {
    viewmodel.specifiedTocActivatedIdentifier$.next(specifiedTocActivatedIdentifier ?? null)
  }, [viewmodel.specifiedTocActivatedIdentifier$, specifiedTocActivatedIdentifier])

  React.useEffect(() => {
    viewmodel.mode$.next(mode ?? viewmodel.mode$.getSnapshot())
  }, [viewmodel.mode$, mode])

  return <React.Fragment />
}

SideEffect.displayName = 'MarkdownViewSideEffect'
