import React from 'react'

export interface IWhiteboardCanvasShellProps {
  readonly canvasRef: React.RefObject<HTMLCanvasElement | null>
  readonly topLeftIsland?: React.ReactNode
  readonly topCenterIsland?: React.ReactNode
  readonly topRightIsland?: React.ReactNode
  readonly bottomLeftIsland?: React.ReactNode
  readonly bottomCenterIsland?: React.ReactNode
  readonly bottomRightIsland?: React.ReactNode
  readonly floatingRightPanel?: React.ReactNode
  readonly centerOverlay?: React.ReactNode
  readonly onPointerDown?: React.PointerEventHandler<HTMLCanvasElement>
  readonly onPointerMove?: React.PointerEventHandler<HTMLCanvasElement>
  readonly onPointerUp?: React.PointerEventHandler<HTMLCanvasElement>
  readonly onPointerCancel?: React.PointerEventHandler<HTMLCanvasElement>
  readonly onDoubleClick?: React.MouseEventHandler<HTMLCanvasElement>
  readonly onWheel?: React.WheelEventHandler<HTMLCanvasElement>
}

export const WhiteboardCanvasShell: React.FC<IWhiteboardCanvasShellProps> = ({
  canvasRef,
  topLeftIsland,
  topCenterIsland,
  topRightIsland,
  bottomLeftIsland,
  bottomCenterIsland,
  bottomRightIsland,
  floatingRightPanel,
  centerOverlay,
  onPointerDown,
  onPointerMove,
  onPointerUp,
  onPointerCancel,
  onDoubleClick,
  onWheel,
}) => {
  return (
    <div className="relative h-full w-full overflow-hidden bg-white">
      <canvas
        ref={canvasRef}
        className="absolute inset-0 h-full w-full touch-none"
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onPointerCancel={onPointerCancel}
        onDoubleClick={onDoubleClick}
        onWheel={onWheel}
      />
      {topLeftIsland && (
        <div className="pointer-events-none absolute left-3 top-3 z-20 md:left-4 md:top-4">
          <div className="pointer-events-auto">{topLeftIsland}</div>
        </div>
      )}
      {topCenterIsland && (
        <div className="pointer-events-none absolute left-1/2 top-3 z-20 -translate-x-1/2 md:top-4">
          <div className="pointer-events-auto">{topCenterIsland}</div>
        </div>
      )}
      {topRightIsland && (
        <div className="pointer-events-none absolute right-3 top-3 z-20 hidden md:block md:right-4 md:top-4">
          <div className="pointer-events-auto">{topRightIsland}</div>
        </div>
      )}
      {floatingRightPanel && (
        <div className="pointer-events-none absolute right-3 top-16 z-20 w-[min(280px,calc(100%-1.5rem))] md:right-4 md:top-[4.5rem]">
          <div className="pointer-events-auto">{floatingRightPanel}</div>
        </div>
      )}
      {centerOverlay && (
        <div className="pointer-events-none absolute inset-0 z-10 flex items-center justify-center p-4">
          {centerOverlay}
        </div>
      )}
      {bottomLeftIsland && (
        <div className="pointer-events-none absolute bottom-3 left-3 z-20 md:bottom-4 md:left-4">
          <div className="pointer-events-auto">{bottomLeftIsland}</div>
        </div>
      )}
      {bottomCenterIsland && (
        <div className="pointer-events-none absolute bottom-3 left-1/2 z-20 -translate-x-1/2 md:bottom-4">
          <div className="pointer-events-auto">{bottomCenterIsland}</div>
        </div>
      )}
      {bottomRightIsland && (
        <div className="pointer-events-none absolute bottom-3 right-3 z-20 md:bottom-4 md:right-4">
          <div className="pointer-events-auto">{bottomRightIsland}</div>
        </div>
      )}
    </div>
  )
}

WhiteboardCanvasShell.displayName = 'WhiteboardCanvasShell'
