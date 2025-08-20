import { Computed, useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { toast } from 'react-toastify'
import type { ITextFileData } from '@/hook/api/file'
import { useFileResult } from '@/hook/useFileResult'
import { useSingleton } from '@/hook/useSingleton'
import { validateTransformConfig } from '@/shared/util'
import { transformTextToNodes } from '../util/transform'
import type { ITextViewContext } from './context'
import { TextViewContextType } from './context'
import type { ITextViewData, ModeEnum, ViewModeEnum } from './types'
import { TextViewViewModel } from './viewmodel'

const storageKey: string = '#/view/filetype/text'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
  readonly mode?: ModeEnum
  readonly viewMode?: ViewModeEnum
  readonly children: React.ReactNode
}

export const TextViewProvider: React.FC<IProps> = props => {
  const { workspace, filepath, filepathDirtyTick, mode, viewMode, children } = props
  const viewmodel: TextViewViewModel | null = useSingleton<TextViewViewModel>(() => {
    const rawViewData: Partial<ITextViewData> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )
    const viewData: ITextViewData = TextViewViewModel.normalize(rawViewData)

    return new TextViewViewModel({
      workspace,
      filepath,
      mode: mode ?? viewData.mode,
      viewMode: viewMode ?? viewData.viewMode,
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
  readonly filepath: string
  readonly filepathDirtyTick: number
  readonly mode?: ModeEnum
  readonly viewMode?: ViewModeEnum
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, workspace, filepath, filepathDirtyTick, mode, viewMode } = props

  usePersistent(viewmodel)
  useSyncProps(viewmodel, workspace, filepath, mode, viewMode)
  useData(viewmodel, workspace, filepath, filepathDirtyTick)
  useAutoTransform(viewmodel)

  return <React.Fragment />
}

SideEffect.displayName = 'TextViewSideEffect'

// /////////////////////////////////////////////////////////////////////////////////////////////////

const usePersistent = (viewmodel: TextViewViewModel): void => {
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
}

const useSyncProps = (
  viewmodel: TextViewViewModel,
  workspace: string | null,
  filepath: string,
  mode: ModeEnum | undefined,
  viewMode: ViewModeEnum | undefined,
): void => {
  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.workspace$.next(workspace)
  }, [viewmodel, workspace])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.filepath$.next(filepath)
  }, [viewmodel, filepath])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.mode$.next(mode ?? viewmodel.mode$.getSnapshot())
  }, [viewmodel, mode])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.viewMode$.next(viewMode ?? viewmodel.viewMode$.getSnapshot())
  }, [viewmodel, viewMode])
}

const useData = (
  viewmodel: TextViewViewModel,
  workspace: string | null,
  filepath: string,
  filepathDirtyTick: number,
): void => {
  const { data, error } = useFileResult<ITextFileData>(workspace, filepath, filepathDirtyTick)

  React.useEffect(() => {
    if (viewmodel.disposed) return

    if (data) {
      viewmodel.content$.next(data.content)
    } else if (error) {
      viewmodel.content$.next(null)
      toast.error(typeof error === 'string' ? error : String(error))
    } else {
      viewmodel.content$.next(null)
    }
  }, [data, error, viewmodel])
}

const useAutoTransform = (viewmodel: TextViewViewModel): void => {
  const content: string | null = useStateValue<string | null>(viewmodel.content$)

  React.useEffect(() => {
    if (viewmodel.disposed) return

    const transformConfig = viewmodel.transformConfig$.getSnapshot()
    if (content && validateTransformConfig(transformConfig)) {
      const result = transformTextToNodes(content as string, transformConfig)
      if (result.error) {
        viewmodel.records$.next([])
      } else {
        viewmodel.records$.next(result.nodes)
      }
    }
  }, [viewmodel, content])
}
