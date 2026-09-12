import React from 'react'

const paths = {
  select: 'm5 3 14 9-7 1-3 7Z',
  hand: 'M8 12V6a1.5 1.5 0 0 1 3 0v5-7a1.5 1.5 0 0 1 3 0v7-5a1.5 1.5 0 0 1 3 0v6-3a1.5 1.5 0 0 1 3 0v6c0 4-2 7-6 7h-1c-2 0-4-1-5-3l-4-6a1.5 1.5 0 0 1 2-2l2 2Z',
  rectangle: 'M6 4h12a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2Z',
  ellipse: 'M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z',
  diamond: 'm12 2 10 10-10 10L2 12Z',
  edge: 'M4 20 20 4M8 4h12v12',
  stroke: 'm4 16-1 5 5-1L20 8l-4-4Zm10-10 4 4',
  laser: 'M12 3v3m0 12v3M3 12h3m12 0h3M8 12a4 4 0 1 0 8 0 4 4 0 0 0-8 0Z',
  navigate: 'm3 5 6-2 6 2 6-2v16l-6 2-6-2-6 2Zm6-2v16m6-14v16',
  read: 'M3 4h7l2 2 2-2h7v15h-7l-2 2-2-2H3Zm9 2v15',
  eraser: 'm3 14 10-11 8 8-9 10H9Zm4-4 8 8M12 21h9',
  layers: 'm3 8 9-5 9 5-9 5Zm0 5 9 5 9-5M3 18l9 5 9-5',
  visible: 'M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12Zm13 0a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z',
  hidden:
    'm3 3 18 18M10 5h2c6 0 10 7 10 7a19 19 0 0 1-3 4M6 6a22 22 0 0 0-4 6s4 7 10 7c2 0 4-1 5-2',
  text: 'M4 6V4h16v2M12 4v16m-4 0h8',
  markdown: 'M3 18V6l5 6 5-6v12m5-11v11m-3-3 3 3 3-3',
  image:
    'M5 3h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2Zm-2 13 6-6 12 10M16 7h.01',
  lock: 'M7 11V7a5 5 0 0 1 10 0v4M5 11h14v10H5Zm7 4v2',
  unlock: 'M7 11V7a5 5 0 0 1 9-3M5 11h14v10H5Zm7 4v2',
  menu: 'M4 6h16M4 12h16M4 18h16',
  more: 'M5 12h.01M12 12h.01M19 12h.01',
  view: 'M3 4h18v16H3ZM15 4v16',
  home: 'm3 10 9-7 9 7M5 9v12h5v-7h4v7h5V9',
  newBoard: 'M13 3H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V10Zm0 0v7h7M12 12v6m-3-3h6',
  importBoard:
    'M13 3H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V10Zm0 0v7h7M12 12v6m-3-3 3 3 3-3',
  exportBoard:
    'M13 3H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V10Zm0 0v7h7M12 18v-6m-3 3 3-3 3 3',
  exportImage:
    'M12 4H5a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7M3 16l5-5 12 10M8 8h.01M15 3h6v6m-7 1 7-7',
  saveAs:
    'M3 7V6a2 2 0 0 1 2-2h4l2 3h8a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7ZM9 14h6m-3-3v6',
  addImage:
    'M12 3H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7M3 16l5-5 12 10M8 7h.01M18 3v6m-3-3h6',
  link: 'M10 13a4 4 0 0 0 6 0l4-4a4 4 0 0 0-6-6l-2 2M14 11a4 4 0 0 0-6 0l-4 4a4 4 0 0 0 6 6l2-2',
  save: 'M5 3h12l4 4v12a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2ZM7 3v6h10V3M7 21v-8h10v8',
  reload: 'M20 7a8 8 0 0 0-13-3L3 7m0-5v5h5M4 17a8 8 0 0 0 13 3l4-3m0 5v-5h-5',
  reference:
    'M9 21H6a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h7l5 5v3M13 3v5h5M8 12h3M14 16l2-2a3 3 0 0 1 4 4l-2 2M16 18l-2 2a3 3 0 0 1-4-4l2-2',
  edit: 'm4 16-1 5 5-1L20 8l-4-4Zm10-10 4 4M13 21h8',
  delete: 'M3 6h18M9 6V3h6v3M5 6l1 15h12l1-15M10 10v7m4-7v7',
  copy: 'M9 9h12v12H9ZM5 15H3V3h12v2',
  cut: 'M9 9 20 20M9 15l11-11M9 6a3 3 0 1 1-6 0 3 3 0 0 1 6 0ZM9 18a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z',
  paste: 'M8 5H5v16h14V5h-3M8 3h8v4H8ZM8 12h8m-8 4h6',
  duplicate: 'M8 8h13v13H8ZM4 16H3V3h13v1M11 14h7m-3.5-3.5v7',
  group: 'M3 8V3h5m8 0h5v5m0 8v5h-5M8 21H3v-5M7 7h5v5H7Zm5 5h5v5h-5Z',
  ungroup: 'M3 3h7v7H3Zm11 11h7v7h-7ZM14 3h7v7M3 14v7h7',
  rotateLeft: 'M4 9a8 8 0 1 1 0 6M4 3v6h6M12 8v4l3 2',
  rotateRight: 'M20 9a8 8 0 1 0 0 6M20 3v6h-6M12 8v4l-3 2',
  flipHorizontal: 'M12 3v3m0 3v6m0 3v3M3 6v12l6-6Zm18 0v12l-6-6Z',
  flipVertical: 'M3 12h3m3 0h6m3 0h3M6 3h12l-6 6Zm0 18h12l-6-6Z',
  alignLeft: 'M4 3v18M8 5h12v5H8Zm0 9h8v5H8Z',
  alignHorizontalCenter: 'M12 2v3m0 5v4m0 5v3M4 5h16v5H4Zm3 9h10v5H7Z',
  alignRight: 'M20 3v18M4 5h12v5H4Zm4 9h8v5H8Z',
  alignTop: 'M3 4h18M5 8h5v12H5Zm9 0h5v8h-5Z',
  alignVerticalCenter: 'M2 12h3m5 0h4m5 0h3M5 4h5v16H5Zm9 3h5v10h-5Z',
  alignBottom: 'M3 20h18M5 4h5v12H5Zm9 4h5v8h-5Z',
  distributeHorizontal: 'M3 3v18M21 3v18M8 6v12m8-12v12M3 12h5m8 0h5',
  distributeVertical: 'M3 3h18M3 21h18M6 8h12M6 16h12M12 3v5m0 8v5',
  textLeft: 'M4 5h16M4 10h10M4 15h16M4 20h10',
  textCenter: 'M4 5h16M7 10h10M4 15h16M7 20h10',
  textRight: 'M4 5h16M10 10h10M4 15h16M10 20h10',
  fontSize: 'M3 6V4h12v2M9 4v16m-4 0h8M16 12v-2h6v2M19 10v10m-2 0h4',
  bold: 'M7 4h6a4 4 0 0 1 0 8H7Zm0 8h7a4 4 0 0 1 0 8H7Z',
  autoSize: 'M4 9V4h5m6 0h5v5m0 6v5h-5M9 20H4v-5M4 12h16m-3-3 3 3-3 3M7 9l-3 3 3 3',
  fill: 'M12 3s7 8 7 12a7 7 0 0 1-14 0c0-4 7-12 7-12ZM8 16a4 4 0 0 0 4 3',
  noFill: 'M6 4h14v14M18 20H4V6M3 3l18 18',
  lineWidth: 'M4 5h16M4 10h16v2H4Zm0 7h16v4H4Z',
  curve: 'M3 18h5c8 0 0-12 8-12h5M3 15v6M21 3v6',
  addBend: 'M3 18h7V6h11M7 15h6v6H7ZM17 12v8m-4-4h8',
  removeBend: 'M3 18h7V6h11M7 15h6v6H7ZM15 16h6',
  close: 'm6 6 12 12M6 18 18 6',
  check: 'm4 12 5 5L20 6',
  previous: 'M20 12H4m6-6-6 6 6 6',
  next: 'M4 12h16m-6-6 6 6-6 6',
  up: 'M12 20V4m-6 6 6-6 6 6',
  down: 'M12 4v16m-6-6 6 6 6-6',
  chevronDown: 'm6 9 6 6 6-6',
  fit: 'M8 3H3v5m13-5h5v5M3 16v5h5m8 0h5v-5M8 8h8v8H8Z',
  focus: 'M8 3H3v5m13-5h5v5M3 16v5h5m8 0h5v-5M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z',
  play: 'm8 4 12 8-12 8Z',
  stop: 'M5 5h14v14H5Z',
  folder: 'M3 7V6a2 2 0 0 1 2-2h4l2 3h8a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7Z',
  minus: 'M5 12h14',
  plus: 'M5 12h14M12 5v14',
  undo: 'm9 4-5 5 5 5M4 9h10a6 6 0 0 1 0 12',
  redo: 'm15 4 5 5-5 5m5-5H10a6 6 0 0 0 0 12',
  back: 'M5 20h14M12 16V4m-5 7 5 5 5-5',
  backward: 'M12 20V4m-6 10 6 6 6-6',
  forward: 'M12 4v16M6 10l6-6 6 6',
  front: 'M5 4h14M12 8v12m-5-7 5-5 5 5',
  help: 'M9 8a3 3 0 0 1 6 0c0 3-3 3-3 6m0 3h.01M22 12a10 10 0 1 1-20 0 10 10 0 0 1 20 0Z',
} as const

export type IBoardIconName = keyof typeof paths

export const BoardIcon: React.FC<{ name: IBoardIconName }> = ({ name }) => (
  <svg
    className="wb-icon"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth="1.65"
    strokeLinecap="round"
    strokeLinejoin="round"
    aria-hidden="true"
  >
    <path d={paths[name]} />
  </svg>
)

export const BoardIconLabel: React.FC<{ name: IBoardIconName; children: React.ReactNode }> = ({
  name,
  children,
}) => (
  <span className="wb-icon-label">
    <BoardIcon name={name} />
    <span>{children}</span>
  </span>
)
