import { Computed } from '@guanghechen/react-viewmodel'
import JSON5 from 'json5'
import React from 'react'
import { toast } from 'react-toastify'
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
  readonly filepath: string
  readonly filepathDirtyTick: number
  readonly mode?: ModeEnum
  readonly children: React.ReactNode
}

export const JsonViewProvider: React.FC<IProps> = props => {
  const { workspace, filepath, filepathDirtyTick, mode, children } = props
  const viewmodel: JsonViewViewModel | null = useSingleton<JsonViewViewModel>(() => {
    const rawViewData: Partial<IJsonViewData> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )
    const viewData: IJsonViewData = JsonViewViewModel.normalize(rawViewData)
    return new JsonViewViewModel({
      workspace,
      filepath,
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
        workspace={workspace}
        filepath={filepath}
        filepathDirtyTick={filepathDirtyTick}
        mode={mode}
      />
    </React.Fragment>
  )
}

JsonViewProvider.displayName = 'JsonViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectProps {
  readonly viewmodel: JsonViewViewModel
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
  readonly mode?: ModeEnum
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, workspace, filepath, filepathDirtyTick, mode } = props

  usePersistent(viewmodel)
  useSyncProps(viewmodel, workspace, filepath, mode)
  useData(viewmodel, workspace, filepath, filepathDirtyTick)

  return <React.Fragment />
}

SideEffect.displayName = 'JsonViewSideEffect'

// /////////////////////////////////////////////////////////////////////////////////////////////////

const usePersistent = (viewmodel: JsonViewViewModel): void => {
  React.useEffect(() => {
    const computed = Computed.fromObservables([viewmodel.mode$], () => {
      const data: IJsonViewData = viewmodel.dump()
      window.localStorage.setItem(storageKey, JSON.stringify(data))
    })
    return (): void => {
      computed.dispose()
    }
  }, [viewmodel])
}

const useSyncProps = (
  viewmodel: JsonViewViewModel,
  workspace: string | null,
  filepath: string,
  mode: ModeEnum | undefined,
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
}

const useData = (
  viewmodel: JsonViewViewModel,
  workspace: string | null,
  filepath: string,
  filepathDirtyTick: number,
): void => {
  const { data, error } = useFileResult<IJsonFileData>(workspace, filepath, filepathDirtyTick)

  React.useEffect(() => {
    if (viewmodel.disposed) return

    if (data) {
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
      toast.error(typeof error === 'string' ? error : String(error))
    } else {
      viewmodel.content$.next(null)
      viewmodel.json$.next(null)
    }
  }, [data, error, viewmodel])
}
