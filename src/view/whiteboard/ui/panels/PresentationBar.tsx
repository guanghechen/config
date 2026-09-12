import React from 'react'
import type { IRegion } from '@/shared/whiteboard/model'
import type { ITool } from '../../interaction/tools'
import { hasBoardDialog, ownsBoardEvent, typing } from '../../interaction/targets'
import { BoardIcon, BoardIconLabel } from '../BoardIcon'

export const PresentationBar: React.FC<{
  currentStep: number | null
  currentArea?: IRegion
  stepCount: number
  tool: ITool
  setTool: (tool: ITool) => void
  setPresenting: (index: number) => void
  stopPresentation: () => void
  focusArea: (region: IRegion) => void
}> = ({
  currentStep,
  currentArea,
  stepCount,
  tool,
  setTool,
  setPresenting,
  stopPresentation,
  focusArea,
}) => {
  const element = React.useRef<HTMLDivElement>(null)
  React.useEffect(() => {
    if (currentArea) focusArea(currentArea)
  }, [currentArea, focusArea])
  React.useEffect(() => {
    const keydown = (event: KeyboardEvent): void => {
      if (
        event.defaultPrevented ||
        !ownsBoardEvent(element.current, event.target) ||
        event.ctrlKey ||
        event.metaKey ||
        event.altKey ||
        hasBoardDialog(element.current) ||
        typing(event.target)
      )
        return
      const key = event.key
      if (
        (key === ' ' || key === 'Enter') &&
        event.target instanceof Element &&
        event.target.closest('button,summary,a')
      )
        return
      if (
        ![
          'Escape',
          'ArrowRight',
          'ArrowDown',
          'PageDown',
          ' ',
          'ArrowLeft',
          'ArrowUp',
          'PageUp',
          'Home',
          'End',
        ].includes(key)
      )
        return
      event.preventDefault()
      event.stopImmediatePropagation()
      if (key === 'Escape') stopPresentation()
      else if (key === 'Home') setPresenting(0)
      else if (key === 'End') setPresenting(Math.max(0, stepCount - 1))
      else
        setPresenting(
          Math.max(
            0,
            Math.min(
              stepCount - 1,
              (currentStep ?? 0) + (['ArrowLeft', 'ArrowUp', 'PageUp'].includes(key) ? -1 : 1),
            ),
          ),
        )
    }
    window.addEventListener('keydown', keydown, true)
    return () => window.removeEventListener('keydown', keydown, true)
  })
  return (
    <div ref={element} className="wb-presentation" data-wb-ui>
      <button
        aria-label="Previous step"
        disabled={!currentStep}
        onClick={() => setPresenting(Math.max(0, (currentStep ?? 0) - 1))}
      >
        <BoardIcon name="previous" />
      </button>
      <span>
        {stepCount
          ? `${(currentStep ?? 0) + 1} / ${stepCount} · ${currentArea?.name ?? ''}`
          : 'No presentation steps'}
      </span>
      <button
        aria-label="Next step"
        disabled={(currentStep ?? 0) >= stepCount - 1}
        onClick={() => setPresenting(Math.min(stepCount - 1, (currentStep ?? 0) + 1))}
      >
        <BoardIcon name="next" />
      </button>
      <button aria-label="Hand" aria-pressed={tool === 'hand'} onClick={() => setTool('hand')}>
        <BoardIcon name="hand" />
      </button>
      <button
        aria-label="Laser pointer"
        aria-pressed={tool === 'laser'}
        onClick={() => setTool('laser')}
      >
        <BoardIcon name="laser" />
      </button>
      <button onClick={stopPresentation}>
        <BoardIconLabel name="stop">Exit presentation</BoardIconLabel>
      </button>
    </div>
  )
}
