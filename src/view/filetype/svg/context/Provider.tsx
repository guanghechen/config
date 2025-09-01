import React from 'react'
import { toast } from 'react-toastify'
import { usePersistAsync } from '@/hook/usePersistAsync'
import { useViewModel } from '@/hook/useViewModel'
import { universalStorage } from '@/util/storage'
import type { ISvgViewContext } from './context'
import { SvgViewContextType } from './context'
import type { ISvgViewData, ISvgViewPosition, ModeEnum } from './types'
import { SvgViewViewModel } from './viewmodel'

interface IProps {
  readonly content: string | null
  readonly contentError: string | null
  readonly mode?: ModeEnum
  readonly scale?: number
  readonly rotation?: number
  readonly position?: ISvgViewPosition
  readonly storageKeyScope: string
  readonly children: React.ReactNode
}

export const SvgViewProvider: React.FC<IProps> = props => {
  const { content, contentError, mode, scale, rotation, position, storageKeyScope, children } =
    props
  const storageKey = `${storageKeyScope}/filetype/svg`
  const viewmodel: SvgViewViewModel | null = useViewModel<SvgViewViewModel>(async () => {
    const rawViewData = await universalStorage.getContext(storageKey)
    const viewData: ISvgViewData = SvgViewViewModel.normalize(rawViewData)
    return new SvgViewViewModel({
      mode: mode ?? viewData.mode,
      scale: scale ?? viewData.scale,
      rotation: rotation ?? viewData.rotation,
      position: position ?? viewData.position,
    })
  })

  const context: ISvgViewContext | null = React.useMemo<ISvgViewContext | null>(
    () => (viewmodel ? { viewmodel } : null),
    [viewmodel],
  )

  if (!viewmodel || !context) return <React.Fragment />

  return (
    <React.Fragment>
      <SvgViewContextType.Provider value={context}>{children}</SvgViewContextType.Provider>
      <SideEffect
        viewmodel={viewmodel}
        content={content}
        contentError={contentError}
        mode={mode}
        scale={scale}
        rotation={rotation}
        position={position}
        storageKey={storageKey}
      />
    </React.Fragment>
  )
}

SvgViewProvider.displayName = 'SvgViewProvider'

// /////////////////////////////////////////////////////////////////////////////////////////////////

interface ISideEffectProps {
  readonly viewmodel: SvgViewViewModel
  readonly content: string | null
  readonly contentError: string | null
  readonly mode?: ModeEnum
  readonly scale?: number
  readonly rotation?: number
  readonly position?: ISvgViewPosition
  readonly storageKey: string
}

const SideEffect: React.FC<ISideEffectProps> = props => {
  const { viewmodel, content, contentError, mode, scale, rotation, position, storageKey } = props

  usePersistAsync(viewmodel, storageKey, [
    viewmodel.mode$,
    viewmodel.scale$,
    viewmodel.rotation$,
    viewmodel.position$,
  ])
  useSyncProps(viewmodel, mode, scale, rotation, position)
  useData(viewmodel, content, contentError)

  return <React.Fragment />
}

SideEffect.displayName = 'SvgViewSideEffect'

// /////////////////////////////////////////////////////////////////////////////////////////////////

const useSyncProps = (
  viewmodel: SvgViewViewModel,
  mode: ModeEnum | undefined,
  scale: number | undefined,
  rotation: number | undefined,
  position: ISvgViewPosition | undefined,
): void => {
  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.mode$.next(mode ?? viewmodel.mode$.getSnapshot())
  }, [viewmodel, mode])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.scale$.next(scale ?? viewmodel.scale$.getSnapshot())
  }, [viewmodel, scale])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.rotation$.next(rotation ?? viewmodel.rotation$.getSnapshot())
  }, [viewmodel, rotation])

  React.useEffect(() => {
    if (viewmodel.disposed) return
    viewmodel.position$.next(position ?? viewmodel.position$.getSnapshot())
  }, [viewmodel, position])
}

const useData = (
  viewmodel: SvgViewViewModel,
  content: string | null,
  contentError: string | null,
): void => {
  React.useEffect(() => {
    if (viewmodel.disposed) return

    if (contentError) {
      viewmodel.content$.next(null)
      toast.error(typeof contentError === 'string' ? contentError : String(contentError))
    } else {
      viewmodel.content$.next(content)
    }
  }, [content, contentError, viewmodel])
}
