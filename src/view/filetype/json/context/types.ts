export enum ModeEnum {
  VIEW = 1,
  LITERAL = 2,
}

export interface IJsonViewData {
  readonly mode: ModeEnum
}
