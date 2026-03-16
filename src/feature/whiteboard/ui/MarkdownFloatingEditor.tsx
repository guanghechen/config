import Editor from '@monaco-editor/react'
import React from 'react'

export interface IMarkdownFloatingEditorProps {
  readonly open: boolean
  readonly value: string
  readonly onClose: () => void
  readonly onSave: (value: string) => void
}

export const MarkdownFloatingEditor: React.FC<IMarkdownFloatingEditorProps> = ({
  open,
  value,
  onClose,
  onSave,
}) => {
  const [draftValue, setDraftValue] = React.useState<string>(value)

  React.useEffect(() => {
    setDraftValue(value)
  }, [value])

  if (!open) return null

  return (
    <div className="pointer-events-auto fixed inset-0 z-50 flex items-center justify-center bg-slate-900/25 p-4 backdrop-blur-[1px]">
      <div className="flex h-[70vh] w-[min(960px,100%)] flex-col overflow-hidden rounded-xl border border-slate-200 bg-white shadow-2xl">
        <div className="flex items-center justify-between border-b border-slate-200 px-4 py-2">
          <div>
            <div className="text-sm font-semibold text-slate-900">Markdown Node Editor</div>
            <div className="text-xs text-slate-500">Single-instance floating Monaco editor</div>
          </div>
          <button
            type="button"
            className="rounded-md border border-slate-300 px-2 py-1 text-xs text-slate-700 hover:bg-slate-100"
            onClick={onClose}
          >
            Close
          </button>
        </div>
        <div className="min-h-0 flex-1">
          <Editor
            height="100%"
            defaultLanguage="markdown"
            language="markdown"
            value={draftValue}
            onChange={next => setDraftValue(next ?? '')}
            options={{
              minimap: { enabled: false },
              fontSize: 13,
              wordWrap: 'on',
              lineNumbers: 'on',
            }}
          />
        </div>
        <div className="flex justify-end gap-2 border-t border-slate-200 px-4 py-2">
          <button
            type="button"
            className="rounded-md border border-slate-300 px-3 py-1 text-xs font-medium text-slate-700 hover:bg-slate-100"
            onClick={onClose}
          >
            Cancel
          </button>
          <button
            type="button"
            className="rounded-md border border-slate-900 bg-slate-900 px-3 py-1 text-xs font-medium text-white hover:bg-slate-700"
            onClick={() => onSave(draftValue)}
          >
            Save
          </button>
        </div>
      </div>
    </div>
  )
}

MarkdownFloatingEditor.displayName = 'MarkdownFloatingEditor'
