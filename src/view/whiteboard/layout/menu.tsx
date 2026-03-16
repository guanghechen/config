import cn from 'clsx'
import React from 'react'

interface IMenuProps {
  readonly inspectorVisible: boolean
  readonly onToggleInspector: () => void
}

export const Menu: React.FC<IMenuProps> = ({ inspectorVisible, onToggleInspector }) => {
  return (
    <div className="flex items-center gap-1">
      <span className="rounded-md bg-slate-100 px-2 py-1 text-[11px] font-semibold text-slate-500">
        WB
      </span>
      <button
        type="button"
        onClick={onToggleInspector}
        className={cn(
          'h-7 rounded-md border px-2 text-[11px] font-medium transition-colors',
          inspectorVisible
            ? 'border-slate-300 bg-slate-900 text-white hover:bg-slate-700'
            : 'border-slate-300 bg-white text-slate-600 hover:bg-slate-100',
        )}
      >
        Inspector
      </button>
    </div>
  )
}

Menu.displayName = 'WhiteboardViewMenu'
