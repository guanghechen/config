import { Computed } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useFileResult } from '@/hook/useFileResult'
import type { IJsonlFileData } from '@/util/fetch'
import { JsonlViewContextType } from './context'
import type { DisplayMode, IChainPath, IJsonlViewData, IJsonlViewRecord, ModeEnum } from './types'
import { JsonlViewViewModel } from './viewmodel'

const storageKey: string = '@guanghechen/yozora/jsonl-view'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
  readonly mode?: ModeEnum
  readonly activeRecordIndex?: number | null
  readonly chainPaths?: IChainPath[]
  readonly displayMode?: DisplayMode
  readonly children: React.ReactNode
}

export const JsonlViewProvider: React.FC<IProps> = props => {
  const {
    workspace,
    filepath,
    filepathDirtyTick,
    mode,
    activeRecordIndex,
    chainPaths,
    displayMode,
    children,
  } = props
  const [viewmodel] = React.useState<JsonlViewViewModel>(() => {
    const initialData: Partial<IJsonlViewData> = JSON.parse(
      window.localStorage.getItem(storageKey) || '{}',
    )
    return JsonlViewViewModel.fromData({
      mode: mode ?? initialData.mode,
      chainPaths: chainPaths ?? initialData.chainPaths,
      displayMode: displayMode ?? initialData.displayMode,
    })
  })
  const value = React.useMemo(() => ({ viewmodel }), [viewmodel])

  return (
    <React.Fragment>
      <JsonlViewContextType.Provider value={value}>{children}</JsonlViewContextType.Provider>
      <SideEffect
        viewmodel={viewmodel}
        workspace={workspace}
        filepath={filepath}
        filepathDirtyTick={filepathDirtyTick}
        mode={mode}
        activeRecordIndex={activeRecordIndex}
        chainPaths={chainPaths}
        displayMode={displayMode}
      />
    </React.Fragment>
  )
}

JsonlViewProvider.displayName = 'JsonlViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectProps {
  readonly viewmodel: JsonlViewViewModel
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
  readonly mode?: ModeEnum
  readonly activeRecordIndex?: number | null
  readonly chainPaths?: IChainPath[]
  readonly displayMode?: DisplayMode
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const {
    viewmodel,
    workspace,
    filepath,
    filepathDirtyTick,
    mode,
    activeRecordIndex,
    chainPaths,
    displayMode,
  } = props

  const { data, error } = useFileResult<IJsonlFileData>(workspace, filepath, filepathDirtyTick)

  React.useEffect(() => {
    if (data?.content) {
      viewmodel.content$.next(data.content)
      viewmodel.error$.next(null)

      // Parse JSONL content into JSON records
      const lines = data.content.split('\n').filter(line => line.trim())
      const records: IJsonlViewRecord[] = []

      lines.forEach((line, index) => {
        try {
          const parsedData = JSON.parse(line)
          records.push({
            index: index + 1,
            content: line,
            parsed: parsedData,
            isValid: true,
          })
        } catch (_parseError) {
          records.push({
            index: index + 1,
            content: line,
            isValid: false,
          })
        }
      })

      viewmodel.jsons$.next(records)
    } else if (error) {
      viewmodel.content$.next(null)
      viewmodel.jsons$.next([])
      viewmodel.error$.next(typeof error === 'string' ? error : String(error))
    } else {
      viewmodel.content$.next(null)
      viewmodel.jsons$.next([])
      viewmodel.error$.next(null)
    }
  }, [data, error, viewmodel])

  React.useEffect(() => {
    const computed = Computed.fromObservables(
      [viewmodel.mode$, viewmodel.chainPaths$, viewmodel.displayMode$],
      () => {
        const data: IJsonlViewData = viewmodel.dump()
        window.localStorage.setItem(storageKey, JSON.stringify(data))
      },
    )
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
    viewmodel.mode$.next(mode ?? viewmodel.mode$.getSnapshot())
  }, [viewmodel.mode$, mode])

  React.useEffect(() => {
    viewmodel.activeRecordIndex$.next(activeRecordIndex ?? null)
  }, [viewmodel.activeRecordIndex$, activeRecordIndex])

  React.useEffect(() => {
    viewmodel.chainPaths$.next(chainPaths ?? viewmodel.chainPaths$.getSnapshot())
  }, [viewmodel.chainPaths$, chainPaths])

  React.useEffect(() => {
    viewmodel.displayMode$.next(displayMode ?? viewmodel.displayMode$.getSnapshot())
  }, [viewmodel.displayMode$, displayMode])

  return <React.Fragment />
}

SideEffect.displayName = 'JsonlViewSideEffect'
