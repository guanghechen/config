export const BOARD_DIALOG_SELECTOR = '.wb-editor,.wb-label-editor,.wb-reference,[aria-modal="true"]'

export const ownsBoardEvent = (element: Element | null, target: EventTarget | null): boolean => {
  const board = element?.closest('[data-whiteboard]')
  return !!board && target instanceof Element && target.closest('[data-whiteboard]') === board
}

export const hasBoardDialog = (element: Element | null): boolean =>
  !!element?.closest('[data-whiteboard]')?.querySelector(BOARD_DIALOG_SELECTOR)

export const typing = (target: EventTarget | null): boolean =>
  target instanceof Element &&
  !!target.closest(
    'input,textarea,select,dialog,[contenteditable="true"],.monaco-editor,[role="dialog"],[role="menu"]',
  )
