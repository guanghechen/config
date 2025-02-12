export enum ServerCustomEventType {
  FILE_CHANGED = 'guanghechen/file-changed',
  FILE_SWITCHED = 'guanghechen/file-switch',
}

export interface IResponsePayloadFileChanged {
  readonly filepath: string
}

export interface IResponsePayloadFileSwitch {
  readonly filepath: string
}
