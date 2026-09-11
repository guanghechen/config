import React from 'react'
import type { IPoint } from '@/shared/whiteboard/model'

export const LabelEditor: React.FC<{
  label: string
  position: IPoint
  viewport: { width: number; height: number }
  onSave: (label: string) => void
  onClose: () => void
}> = ({ label, position, viewport, onSave, onClose }) => {
  const [draft, setDraft] = React.useState(label)
  React.useEffect(() => {
    const guard = (event: BeforeUnloadEvent): void => {
      if (draft !== label) event.preventDefault()
    }
    window.addEventListener('beforeunload', guard)
    return () => window.removeEventListener('beforeunload', guard)
  }, [draft, label])
  return (
    <form
      className="wb-label-editor"
      data-wb-ui
      role="dialog"
      aria-label="Edit label"
      style={{
        left: Math.max(12, Math.min(position.x - 150, viewport.width - 312)),
        top: Math.max(80, Math.min(position.y - 60, viewport.height - 200)),
      }}
      onSubmit={event => {
        event.preventDefault()
        onSave(draft)
      }}
      onKeyDown={event => {
        event.stopPropagation()
        if (event.nativeEvent.isComposing) return
        if (event.key === 'Escape') {
          event.preventDefault()
          onClose()
        }
        if (event.key === 'Enter' && !event.shiftKey) {
          event.preventDefault()
          onSave(draft)
        }
      }}
    >
      <textarea
        aria-label="Label text"
        autoFocus
        maxLength={4000}
        rows={3}
        value={draft}
        onFocus={event => event.currentTarget.select()}
        onChange={event => setDraft(event.target.value)}
      />
      <footer>
        <small>Shift + Enter for a new line</small>
        <button type="button" onClick={onClose}>
          Cancel
        </button>
        <button className="wb-primary" type="submit">
          Save
        </button>
      </footer>
    </form>
  )
}
