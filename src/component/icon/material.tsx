import React from 'react'

export interface IIconProps {
  readonly fill?: string
  readonly className?: string
}

export const CheckIcon: React.FC<IIconProps> = props => {
  const { fill = 'currentColor', className } = props
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      height="24px"
      viewBox="0 -960 960 960"
      width="24px"
      fill={fill}
      className={className}
    >
      <path d="M382-240 154-468l57-57 171 171 367-367 57 57-424 424Z" />
    </svg>
  )
}

export const ChevronDownIcon: React.FC<IIconProps> = props => {
  const { fill = 'currentColor', className } = props
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      height="24px"
      viewBox="0 -960 960 960"
      width="24px"
      fill={fill}
      className={className}
    >
      <path d="M240-400l240 240 240-240-56-56-184 184-184-184-56 56Z" />
    </svg>
  )
}

export const ChevronLeftIcon: React.FC<IIconProps> = props => {
  const { fill = 'currentColor', className } = props
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      height="24px"
      viewBox="0 -960 960 960"
      width="24px"
      fill={fill}
      className={className}
    >
      <path d="M560-240 320-480l240-240 56 56-184 184 184 184-56 56Z" />
    </svg>
  )
}

export const ChevronRightIcon: React.FC<IIconProps> = props => {
  const { fill = 'currentColor', className } = props
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      height="24px"
      viewBox="0 -960 960 960"
      width="24px"
      fill={fill}
      className={className}
    >
      <path d="M504-480 320-664l56-56 240 240-240 240-56-56 184-184Z" />
    </svg>
  )
}

export const ChevronUpIcon: React.FC<IIconProps> = props => {
  const { fill = 'currentColor', className } = props
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      height="24px"
      viewBox="0 -960 960 960"
      width="24px"
      fill={fill}
      className={className}
    >
      <path d="M720-560L480-320 240-560l56-56 184 184 184-184 56 56Z" />
    </svg>
  )
}

export const CodeIcon: React.FC<IIconProps> = props => {
  const { fill = 'currentColor', className } = props
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      height="24px"
      viewBox="0 -960 960 960"
      width="24px"
      fill={fill}
      className={className}
    >
      <path d="M320-240 80-480l240-240 57 57-184 184 183 183-56 56Zm320 0-57-57 184-184-183-183 56-56 240 240-240 240Z" />
    </svg>
  )
}

export const CopyIcon: React.FC<IIconProps> = props => {
  const { fill = 'currentColor', className } = props
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      height="24px"
      viewBox="0 -960 960 960"
      width="24px"
      fill={fill}
      className={className}
    >
      <path d="M360-240q-33 0-56.5-23.5T280-320v-480q0-33 23.5-56.5T360-880h360q33 0 56.5 23.5T800-800v480q0 33-23.5 56.5T720-240H360Zm0-80h360v-480H360v480ZM200-80q-33 0-56.5-23.5T120-160v-560h80v560h440v80H200Zm160-240v-480 480Z" />
    </svg>
  )
}

export const FileIcon: React.FC<IIconProps> = props => {
  const { fill = 'currentColor', className } = props
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      height="24px"
      viewBox="0 -960 960 960"
      width="24px"
      fill={fill}
      className={className}
    >
      <path d="M320-240q-33 0-56.5-23.5T240-320v-480q0-33 23.5-56.5T320-880h480q33 0 56.5 23.5T880-800v480q0 33-23.5 56.5T800-240H320Zm0-80h480v-480H320v480ZM160-80q-33 0-56.5-23.5T80-160v-560h80v560h560v80H160Zm160-240v-480 480Z" />
    </svg>
  )
}

export const FolderIcon: React.FC<IIconProps> = props => {
  const { fill = 'currentColor', className } = props
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      height="24px"
      viewBox="0 -960 960 960"
      width="24px"
      fill={fill}
      className={className}
    >
      <path d="M160-160q-33 0-56.5-23.5T80-240v-480q0-33 23.5-56.5T160-800h240l80 80h320q33 0 56.5 23.5T880-640v400q0 33-23.5 56.5T800-160H160Zm0-80h640v-400H447l-80-80H160v480Zm0 0v-480 480Z" />
    </svg>
  )
}

export const FolderOpenIcon: React.FC<IIconProps> = props => {
  const { fill = 'currentColor', className } = props
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      height="24px"
      viewBox="0 -960 960 960"
      width="24px"
      fill={fill}
      className={className}
    >
      <path d="M160-160q-33 0-56.5-23.5T80-240v-480q0-33 23.5-56.5T160-800h240l80 80h320q33 0 56.5 23.5T880-640H447l-80-80H160v480l96-320h684L837-217q-8 26-29.5 41.5T760-160H160Zm84-80h516l72-240H316l-72 240Zm0 0 72-240-72 240Zm-84-400v-80 80Z" />
    </svg>
  )
}

export const TerminalIcon: React.FC<IIconProps> = props => {
  const { fill = 'currentColor', className } = props
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      height="24px"
      viewBox="0 -960 960 960"
      width="24px"
      fill={fill}
      className={className}
    >
      <path d="M160-160q-33 0-56.5-23.5T80-240v-480q0-33 23.5-56.5T160-800h640q33 0 56.5 23.5T880-720v480q0 33-23.5 56.5T800-160H160Zm0-80h640v-400H160v400Zm140-40-56-56 103-104-104-104 57-56 160 160-160 160Zm180 0v-80h240v80H480Z" />
    </svg>
  )
}
