import React from 'react'
import { ViewLayout } from '@/container/ViewLayout'
import { Main } from './layout/main'
import { Sidebar } from './layout/sidebar'

export const Composer: React.FC = () => {
  const [inspectorVisible, setInspectorVisible] = React.useState<boolean>(false)

  const onToggleInspector = React.useCallback((): void => {
    setInspectorVisible(visible => !visible)
  }, [])

  return (
    <ViewLayout
      scenario="whiteboard"
      settings={
        <button
          type="button"
          className="rounded-md border border-slate-200 bg-white px-2 py-1 text-[11px] text-slate-600 hover:bg-slate-100"
          onClick={onToggleInspector}
        >
          Inspector
        </button>
      }
      sidebar={inspectorVisible ? <Sidebar /> : undefined}
    >
      <Main />
    </ViewLayout>
  )
}

Composer.displayName = 'WhiteboardViewComposer'
