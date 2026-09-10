export enum ServerCustomEventType {
  FILE_CHANGED = 'guanghechen/file-changed',
  FILE_SWITCHED = 'guanghechen/file-switch',
  FILE_SWITCH_ASK = 'guanghechen/file-switch-ask',
}

export interface IResponsePayloadFileChanged {
  readonly filepath: string
}

export interface IResponsePayloadFileSwitch {
  readonly filepath: string
}
