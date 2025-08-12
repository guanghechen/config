import React from 'react'
import { useFileResult } from '@/hook/useFileResult'
import type { IMarkdownFileData } from '@/util/fetch'
import { MarkdownViewContextType } from './context'
import { ModeEnum } from './types'
import { MarkdownViewViewModel } from './viewmodel'

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
  const [viewmodel] = React.useState<MarkdownViewViewModel>(
    () =>
      new MarkdownViewViewModel({
        workspace,
        filepath,
        tocActivatedIdentifier,
        specifiedTocActivatedIdentifier,
        mode,
      }),
  )
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
    viewmodel.mode$.next(mode ?? ModeEnum.VIEW)
  }, [viewmodel.mode$, mode])

  return <React.Fragment />
}

SideEffect.displayName = 'MarkdownViewSideEffect'
