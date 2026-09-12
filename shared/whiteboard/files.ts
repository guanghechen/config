export function isWhiteboardFilename(value: unknown): value is string {
  return (
    typeof value === 'string' &&
    /^[^/\\]{1,180}\.whiteboard$/i.test(value) &&
    !Array.from(value).some(character => character.charCodeAt(0) < 32)
  )
}
