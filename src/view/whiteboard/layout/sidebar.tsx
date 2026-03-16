import React from 'react'

export const Sidebar: React.FC = () => {
  return (
    <div className="h-full w-full border-r border-slate-200 bg-white px-3 py-3 text-sm text-slate-700">
      <h2 className="mb-2 text-sm font-semibold text-slate-900">Inspector</h2>
      <div className="space-y-2 text-xs leading-5 text-slate-600">
        <p>已接入 Phase A 基础交互：node/edge 创建、lasso、多选拖拽、resize、undo/redo。</p>
        <p>
          支持 markdown floating editor、clipboard 与 z-index 控制、edge 和 image path validation。
        </p>
        <p>后续会把 node/edge/port 属性编辑器与 command 事件调试面板接入到这里。</p>
      </div>
    </div>
  )
}

Sidebar.displayName = 'WhiteboardViewSidebar'
