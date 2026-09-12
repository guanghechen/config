import React from 'react'
import type { IWhiteboardEditorProps } from '../../contracts'

export const PlainTextEditor: React.FC<IWhiteboardEditorProps> = ({
  initialValue,
  readOnly,
  onChange,
  onMount,
}) => {
  const input = React.useRef<HTMLTextAreaElement>(null)
  React.useEffect(() => {
    const element = input.current!
    onMount({ getValue: () => element.value, focus: () => element.focus() })
  }, [onMount])
  return (
    <textarea
      ref={input}
      className="wb-plain-editor"
      aria-label="Content"
      defaultValue={initialValue}
      readOnly={readOnly}
      onChange={event => onChange(event.target.value)}
    />
  )
}
