import { useComputed, useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { useDrawboardContext } from '../context'
import type { IDrawboardElement } from '../types/elements'

interface ISelectionBoxProps {
  element: IDrawboardElement
  viewData: any
}

const SelectionBox: React.FC<ISelectionBoxProps> = ({ element, viewData }) => {
  const x = element.x * viewData.zoom.value + viewData.offsetX
  const y = element.y * viewData.zoom.value + viewData.offsetY
  const width = element.width * viewData.zoom.value
  const height = element.height * viewData.zoom.value

  return (
    <div
      className="absolute pointer-events-none border-2 border-blue-500"
      style={{
        left: x - 2,
        top: y - 2,
        width: width + 4,
        height: height + 4,
        borderColor: 'rgb(59 130 246)', // blue-500
        boxShadow: '0 0 0 1px rgb(255 255 255)', // white
      }}
    >
      {/* Selection handles */}
      <div
        className="absolute -top-1 -left-1 w-2 h-2 bg-blue-500 border border-white rounded-sm"
        style={{ backgroundColor: 'rgb(59 130 246)' }} // blue-500
      />
      <div
        className="absolute -top-1 left-1/2 -translate-x-1/2 w-2 h-2 bg-blue-500 border border-white rounded-sm"
        style={{ backgroundColor: 'rgb(59 130 246)' }} // blue-500
      />
      <div
        className="absolute -top-1 -right-1 w-2 h-2 bg-blue-500 border border-white rounded-sm"
        style={{ backgroundColor: 'rgb(59 130 246)' }} // blue-500
      />
      <div
        className="absolute top-1/2 -translate-y-1/2 -left-1 w-2 h-2 bg-blue-500 border border-white rounded-sm"
        style={{ backgroundColor: 'rgb(59 130 246)' }} // blue-500
      />
      <div
        className="absolute top-1/2 -translate-y-1/2 -right-1 w-2 h-2 bg-blue-500 border border-white rounded-sm"
        style={{ backgroundColor: 'rgb(59 130 246)' }} // blue-500
      />
      <div
        className="absolute -bottom-1 -left-1 w-2 h-2 bg-blue-500 border border-white rounded-sm"
        style={{ backgroundColor: 'rgb(59 130 246)' }} // blue-500
      />
      <div
        className="absolute -bottom-1 left-1/2 -translate-x-1/2 w-2 h-2 bg-blue-500 border border-white rounded-sm"
        style={{ backgroundColor: 'rgb(59 130 246)' }} // blue-500
      />
      <div
        className="absolute -bottom-1 -right-1 w-2 h-2 bg-blue-500 border border-white rounded-sm"
        style={{ backgroundColor: 'rgb(59 130 246)' }} // blue-500
      />
    </div>
  )
}

export const InteractiveCanvas: React.FC = () => {
  const { ui, layers } = useDrawboardContext()
  const selectedElementIds = useStateValue(ui.selectedElementIds$)
  const allElements = useComputed(layers.allElements$)
  const interactionState = useStateValue(ui.interactionState$)

  // Get selected elements
  const selectedElements = React.useMemo(() => {
    const selectedIds = Object.keys(selectedElementIds)
    return (allElements as IDrawboardElement[]).filter(element => selectedIds.includes(element.id))
  }, [allElements, selectedElementIds])

  return (
    <div
      className={cn(
        'drawboard-canvas drawboard-canvas--interactive drawboard-layer--interactive',
        'pointer-events-none',
      )}
    >
      {/* Selection boxes for selected elements */}
      {(selectedElements as IDrawboardElement[]).map((element: IDrawboardElement) => (
        <SelectionBox key={element.id} element={element} viewData={interactionState} />
      ))}
    </div>
  )
}
