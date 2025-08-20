import React from 'react'

interface IProps {
  readonly value: string
  readonly placeholder?: string
  readonly description?: string
  readonly className?: string
  readonly onChange: (value: string) => void
}

export const CodeBox: React.FC<IProps> = props => {
  const { value, placeholder, description, className, onChange } = props
  const textareaRef = React.useRef<HTMLTextAreaElement>(null)

  const adjustHeight = React.useCallback(() => {
    const textarea = textareaRef.current
    if (!textarea) return

    textarea.style.height = 'auto'
    const scrollHeight = textarea.scrollHeight
    const lineHeight = 24
    const minHeight = lineHeight
    const maxHeight = lineHeight * 10

    const newHeight = Math.min(Math.max(scrollHeight, minHeight), maxHeight)
    textarea.style.height = `${newHeight}px`
  }, [])

  React.useEffect(() => {
    adjustHeight()
  }, [value, adjustHeight])

  return (
    <div className={className}>
      {description && (
        <div className="mb-2 text-sm font-medium text-gray-700 dark:text-gray-300">
          {description}
        </div>
      )}
      <textarea
        ref={textareaRef}
        value={value}
        onChange={e => onChange(e.target.value)}
        placeholder={placeholder}
        className="w-full rounded-md border border-gray-300 bg-white px-3 py-2 text-sm font-mono dark:border-gray-600 dark:bg-gray-800 dark:text-gray-200 resize-none overflow-hidden transition-colors duration-200 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 dark:focus:ring-blue-400/20 dark:focus:border-blue-400"
        style={{ minHeight: '24px', maxHeight: '240px' }}
        rows={1}
      />
    </div>
  )
}

CodeBox.displayName = 'CodeBox'
