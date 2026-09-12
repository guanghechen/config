import React from 'react'
import { BoardIcon, BoardIconLabel } from '../BoardIcon'
import type { IBoardIconName } from '../BoardIcon'

export const InspectorSection: React.FC<{
  title: string
  icon: IBoardIconName
  initiallyOpen?: boolean
  disabled?: boolean
  children: React.ReactNode
}> = ({ title, icon, initiallyOpen = false, disabled, children }) => {
  const [open, setOpen] = React.useState(initiallyOpen)
  return (
    <details
      className="wb-inspector-section"
      open={open}
      onToggle={event => setOpen(event.currentTarget.open)}
    >
      <summary>
        <BoardIconLabel name={icon}>{title}</BoardIconLabel>
        <BoardIcon name="chevronDown" />
      </summary>
      <fieldset disabled={disabled} aria-label={title}>
        {children}
      </fieldset>
    </details>
  )
}
