import React from 'react'

const paths = {
  select: 'm5 3 14 9-7 1-3 7Z',
  hand: 'M8 12V6a1.5 1.5 0 0 1 3 0v5-7a1.5 1.5 0 0 1 3 0v7-5a1.5 1.5 0 0 1 3 0v6-3a1.5 1.5 0 0 1 3 0v6c0 4-2 7-6 7h-1c-2 0-4-1-5-3l-4-6a1.5 1.5 0 0 1 2-2l2 2Z',
  rectangle: 'M6 4h12a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2Z',
  ellipse: 'M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z',
  diamond: 'm12 2 10 10-10 10L2 12Z',
  edge: 'M4 20 20 4M8 4h12v12',
  stroke: 'm4 16-1 5 5-1L20 8l-4-4Zm10-10 4 4',
  text: 'M4 6V4h16v2M12 4v16m-4 0h8',
  markdown: 'M3 18V6l5 6 5-6v12m5-11v11m-3-3 3 3 3-3',
  image:
    'M5 3h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2Zm-2 13 6-6 12 10M16 7h.01',
  lock: 'M7 11V7a5 5 0 0 1 10 0v4M5 11h14v10H5Zm7 4v2',
  unlock: 'M7 11V7a5 5 0 0 1 9-3M5 11h14v10H5Zm7 4v2',
  menu: 'M4 6h16M4 12h16M4 18h16',
  home: 'm3 10 9-7 9 7M5 9v12h5v-7h4v7h5V9',
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

export const BoardIcon: React.FC<{ name: keyof typeof paths }> = ({ name }) => (
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
