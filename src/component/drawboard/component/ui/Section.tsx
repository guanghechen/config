import cn from 'clsx'
import React from 'react'

interface ISectionProps {
  title: string
  children: React.ReactNode
  collapsible?: boolean
  defaultOpen?: boolean
}

export const Section: React.FC<ISectionProps> = ({
  title,
  children,
  collapsible = false,
  defaultOpen = true,
}) => {
  const [isOpen, setIsOpen] = React.useState(defaultOpen)

  return (
    <div className="mb-6">
      <div
        className={cn('mb-3 flex items-center justify-between', collapsible && 'cursor-pointer')}
        onClick={collapsible ? () => setIsOpen(!isOpen) : undefined}
      >
        <h4 className="text-xs font-semibold uppercase tracking-wide text-gray-500">{title}</h4>
        {collapsible && (
          <svg
            className={cn('h-4 w-4 text-gray-400 transition-transform', {
              'rotate-180': !isOpen,
            })}
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
          </svg>
        )}
      </div>
      {isOpen && <div className="space-y-3">{children}</div>}
    </div>
  )
}

interface IFieldProps {
  label: string
  children: React.ReactNode
}

export const Field: React.FC<IFieldProps> = ({ label, children }) => {
  return (
    <div className="space-y-1">
      <label className="block text-xs font-medium text-gray-700">{label}</label>
      {children}
    </div>
  )
}
