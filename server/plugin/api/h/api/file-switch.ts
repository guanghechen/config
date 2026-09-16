import state from '../../../../state.ts'
import type { IApiHandle, IApiHandleData } from '../../types.ts'

export const switchFile: IApiHandle = async params => {
  const { searchParams } = params

  const force: boolean = (searchParams.get('force') ?? '').toLowerCase() === 'true'
  const filepath = state.access.resolve(searchParams.get('filepath'), 'file')
  state.fileSwitchArgForce$.next(force)
  state.fileSwitch$.next(filepath)

  const data: IApiHandleData = {
    data: { succeed: true },
  }
  return { code: 200, data }
}
