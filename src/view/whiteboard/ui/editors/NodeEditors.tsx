import React from 'react'
import { labelArea } from '@/shared/whiteboard/geometry'
import type { IBoardSnapshot } from '../../store'
import type { MarkdownResources } from '../../io/resources'
import type { useNodeEditor } from './useNodeEditor'
import { LabelEditor } from './LabelEditor'
const InlineEditor = React.lazy(() =>
  import('./InlineEditor').then(module => ({ default: module.InlineEditor })),
)

export const NodeEditors: React.FC<{
  session: ReturnType<typeof useNodeEditor>
  resources: MarkdownResources
  snapshot: IBoardSnapshot
  size: { width: number; height: number }
}> = ({ session, resources, snapshot, size }) => {
  const { editor, labelEditor } = session
  const editingLabelArea = labelEditor
    ? labelArea(
        labelEditor,
        new Map(snapshot.document.elements.map(element => [element.id, element])),
      )
    : null

  return (
    <>
      {editor && (
        <React.Suspense fallback={<div className="wb-loading">Loading editor…</div>}>
          <InlineEditor
            viewport={size}
            key={editor.node.id}
            session={editor}
            resources={resources}
            onClose={session.closeEditor}
            onSave={session.saveContent}
          />
        </React.Suspense>
      )}
      {labelEditor && editingLabelArea && (
        <LabelEditor
          key={labelEditor.id}
          label={labelEditor.label ?? ''}
          position={{
            x:
              (editingLabelArea.x + editingLabelArea.width / 2) * snapshot.camera.zoom +
              snapshot.camera.x,
            y:
              (editingLabelArea.y + editingLabelArea.height / 2) * snapshot.camera.zoom +
              snapshot.camera.y,
          }}
          viewport={size}
          onClose={session.closeLabel}
          onSave={session.saveLabel}
        />
      )}
    </>
  )
}
