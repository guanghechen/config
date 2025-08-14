import { Computed } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useFileResult } from '@/hook/useFileResult'
import { useSingleton } from '@/hook/useSingleton'
import type { ITextFileData } from '@/util/fetch'
import type { ITextViewContext } from './context'
import { TextViewContextType } from './context'
import type { ITextViewData } from './types'
import { TextViewViewModel } from './viewmodel'

const storageKey: string = '#/view/filetype/text'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string | null
  readonly filepathDirtyTick: number
  readonly children: React.ReactNode
}

export const TextViewProvider: React.FC<IProps> = props => {
  const { workspace, filepath, filepathDirtyTick, children } = props
  const viewmodel: TextViewViewModel | null = useSingleton<TextViewViewModel>(() => {
    const initialData: Partial<ITextViewData> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )
    return TextViewViewModel.fromData(initialData)
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
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, workspace, filepath, filepathDirtyTick } = props

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
    const computed = Computed.fromObservables([viewmodel.content$], () => {
      const data: ITextViewData = viewmodel.dump()
      window.localStorage.setItem(storageKey, JSON.stringify(data))
    })
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

  return <React.Fragment />
}

SideEffect.displayName = 'TextViewSideEffect'

