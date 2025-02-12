export const sleep = (duration: number): Promise<void> =>
  new Promise<void>(resolve => setTimeout(resolve, duration))
