/* eslint-disable react/jsx-pascal-case */
import { Excalidraw as $Excalidraw } from '@excalidraw/excalidraw'
import React from 'react'
import { ElementViewer } from '@/component/ElementViewer'
import '@excalidraw/excalidraw/index.css'

interface IExcalidrawRendererProps {
  readonly code: string
}

const ExcalidrawRenderer: React.FC<IExcalidrawRendererProps> = props => {
  const { code } = props

  // Parse the excalidraw data from the code block
  const excalidrawData = React.useMemo(() => {
    try {
      return JSON.parse(code)
    } catch {
      return null
    }
  }, [code])

  if (!excalidrawData) {
    return <div className="p-4 text-red-500">Invalid Excalidraw data: Unable to parse JSON</div>
  }

  return (
    <div className="size-full">
      <$Excalidraw
        initialData={excalidrawData}
        viewModeEnabled={true}
        zenModeEnabled={false}
        gridModeEnabled={false}
        theme="light"
      />
    </div>
  )
}
ExcalidrawRenderer.displayName = 'ExcalidrawRenderer'

const Excalidraw: React.FC<{ readonly code: string }> = props => {
  const { code } = props
  const [open, setOpen] = React.useState<boolean>(false)

  const onClick = React.useCallback((): void => {
    setOpen(true)
  }, [])

  const onClose = React.useCallback((): void => {
    setOpen(false)
  }, [])

  return (
    <React.Fragment>
      <div
        className="cursor-pointer w-full h-64 flex items-center justify-center border border-gray-200 rounded"
        onClick={onClick}
      >
        <ExcalidrawRenderer code={code} />
      </div>
      <ElementViewer open={open} resetOnOpen={false} onClose={onClose}>
        <div className="w-[90vw] h-[90vh]">
          <ExcalidrawRenderer code={code} />
        </div>
      </ElementViewer>
    </React.Fragment>
  )
}
Excalidraw.displayName = 'CodeRendererExcalidraw'
export default Excalidraw
