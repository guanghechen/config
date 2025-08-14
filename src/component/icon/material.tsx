import React from 'react'

export interface IIconProps {
  readonly fill?: string
  readonly className?: string
}

export const ArrowMenuClose: React.FC<IIconProps> = props => {
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
      <path d="M440-280v-400L240-480l200 200Zm80 160h80v-720h-80v720Z" />
    </svg>
  )
}

export const ArrowMenuOpen: React.FC<IIconProps> = props => {
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
      <path d="M360-120v-720h80v720h-80Zm160-160v-400l200 200-200 200Z" />
    </svg>
  )
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
      <path d="M240-400l240-240 240 240-56 56-184-184-184 184-56-56Z" />
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

export const DockToLeftIcon: React.FC<IIconProps> = props => {
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
      <path d="M200-120q-33 0-56.5-23.5T120-200v-560q0-33 23.5-56.5T200-840h560q33 0 56.5 23.5T840-760v560q0 33-23.5 56.5T760-120H200Zm440-80h120v-560H640v560Zm-80 0v-560H200v560h360Zm80 0h120-120Z" />
    </svg>
  )
}

export const DockToRightIcon: React.FC<IIconProps> = props => {
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
      <path d="M200-120q-33 0-56.5-23.5T120-200v-560q0-33 23.5-56.5T200-840h560q33 0 56.5 23.5T840-760v560q0 33-23.5 56.5T760-120H200Zm120-80v-560H200v560h120Zm80 0h360v-560H400v560Zm-80 0H200h120Z" />
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

export const OpenInNewIcon: React.FC<IIconProps> = props => {
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
      <path d="M200-120q-33 0-56.5-23.5T120-200v-560q0-33 23.5-56.5T200-840h280v80H200v560h560v-280h80v280q0 33-23.5 56.5T760-120H200Zm188-212-56-56 372-372H560v-80h280v280h-80v-144L388-332Z" />
    </svg>
  )
}

export const OpenWithIcon: React.FC<IIconProps> = props => {
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
      <path d="M480-80 310-250l57-57 73 73v-166h80v165l72-73 58 58L480-80ZM250-310 80-480l169-169 57 57-72 72h166v80H235l73 72-58 58Zm460 0-57-57 73-73H560v-80h165l-73-72 58-58 170 170-170 170ZM440-560v-166l-73 73-57-57 170-170 170 170-57 57-73-73v166h-80Z" />
    </svg>
  )
}

export const ResetZoomIcon: React.FC<IIconProps> = props => {
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
      <path d="M520-330v-60h160v60H520Zm60 210v-50h-60v-60h60v-50h60v160h-60Zm100-50v-60h160v60H680Zm40-110v-160h60v50h60v60h-60v50h-60Zm111-280h-83q-26-88-99-144t-169-56q-117 0-198.5 81.5T200-480q0 72 32.5 132t87.5 98v-110h80v240H160v-80h94q-62-50-98-122.5T120-480q0-75 28.5-140.5t77-114q48.5-48.5 114-77T480-840q129 0 226.5 79.5T831-560Z" />
    </svg>
  )
}

export const RotateLeftIcon: React.FC<IIconProps> = props => {
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
      <path d="M520-80q-51 0-100-14t-92-42l58-58q31 17 65 25.5t69 8.5q117 0 198.5-81.5T800-440q0-117-81.5-198.5T520-720h-6l62 62-56 58-160-160 160-160 56 58-62 62h6q150 0 255 105t105 255q0 75-28.5 140.5t-77 114q-48.5 48.5-114 77T520-80ZM280-200 40-440l240-240 240 240-240 240Zm0-114 126-126-126-126-126 126 126 126Zm0-126Z" />
    </svg>
  )
}

export const RotateRightIcon: React.FC<IIconProps> = props => {
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
      <path d="M440-80q-75 0-140.5-28.5t-114-77q-48.5-48.5-77-114T80-440q0-150 105-255t255-105h6l-62-62 56-58 160 160-160 160-56-58 62-62h-6q-117 0-198.5 81.5T160-440q0 117 81.5 198.5T440-160q35 0 69-8.5t65-25.5l58 58q-43 28-92 42T440-80Zm240-120L440-440l240-240 240 240-240 240Zm0-114 126-126-126-126-126 126 126 126Zm0-126Z" />
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

export const ViewPageByPageIcon: React.FC<IIconProps> = props => {
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
      <path d="M450-500q21 0 35.5-14.5T500-550q0-21-14.5-35.5T450-600q-21 0-35.5 14.5T400-550q0 21 14.5 35.5T450-500Zm7 180 223-223-57-57-223 223 57 57Zm173 0q21 0 35.5-14.5T680-370q0-21-14.5-35.5T630-420q-21 0-35.5 14.5T580-370q0 21 14.5 35.5T630-320Zm130 120H320q-33 0-56.5-23.5T240-280v-560q0-33 23.5-56.5T320-920h280l240 240v400q0 33-23.5 56.5T760-200ZM560-640v-200H320v560h440v-360H560ZM160-40q-33 0-56.5-23.5T80-120v-560h80v560h440v80H160Zm160-800v200-200 560-560Z" />
    </svg>
  )
}

export const ViewStreamIcon: React.FC<IIconProps> = props => {
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
      <path d="M760-280v-160H200v160h560Zm0-240v-160H200v160h560ZM200-200q-33 0-56.5-23.5T120-280v-400q0-33 23.5-56.5T200-760h560q33 0 56.5 23.5T840-680v400q0 33-23.5 56.5T760-200H200Z" />
    </svg>
  )
}

export const ZoomInIcon: React.FC<IIconProps> = props => {
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
      <path d="M784-120 532-372q-30 24-69 38t-83 14q-109 0-184.5-75.5T120-580q0-109 75.5-184.5T380-840q109 0 184.5 75.5T640-580q0 44-14 83t-38 69l252 252-56 56ZM380-400q75 0 127.5-52.5T560-580q0-75-52.5-127.5T380-760q-75 0-127.5 52.5T200-580q0 75 52.5 127.5T380-400Zm-40-60v-80h-80v-80h80v-80h80v80h80v80h-80v80h-80Z" />
    </svg>
  )
}

export const ZoomOutIcon: React.FC<IIconProps> = props => {
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
      <path d="M784-120 532-372q-30 24-69 38t-83 14q-109 0-184.5-75.5T120-580q0-109 75.5-184.5T380-840q109 0 184.5 75.5T640-580q0 44-14 83t-38 69l252 252-56 56ZM380-400q75 0 127.5-52.5T560-580q0-75-52.5-127.5T380-760q-75 0-127.5 52.5T200-580q0 75 52.5 127.5T380-400ZM280-540v-80h200v80H280Z" />
    </svg>
  )
}

export const SnippetIcon: React.FC<IIconProps> = props => {
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
      <path d="M360-240 120-480l240-240 56 56-184 184 184 184-56 56Zm240 0-56-56 184-184-184-184 56-56 240 240-240 240Z" />
    </svg>
  )
}
