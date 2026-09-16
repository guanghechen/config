// Union types for all API interfaces
import type {
  IFileSaveRequestParams,
  IFileSaveRequestPayload,
  IFileSaveResponseResult,
  IWhiteboardCreateRequestPayload,
} from './file.ts'
import type {
  ITransformerListRequestParams,
  ITransformerListRequestPayload,
  ITransformerListResponseResult,
  ITransformerResolveRequestParams,
  ITransformerResolveRequestPayload,
  ITransformerResolveResponseResult,
  ITransformerSaveRequestParams,
  ITransformerSaveRequestPayload,
  ITransformerSaveResponseResult,
} from './transform.ts'
import type {
  IUserAuthRequestParams,
  IUserAuthRequestPayload,
  IUserAuthResponseResult,
  IUserLogoutRequestParams,
  IUserLogoutRequestPayload,
  IUserLogoutResponseResult,
  IUserProfileRequestParams,
  IUserProfileRequestPayload,
  IUserProfileResponseResult,
} from './user.ts'

export * from './event.ts'
export * from './file.ts'
export * from './transform.ts'
export * from './user.ts'

export type IRequestParams =
  | IFileSaveRequestParams
  | IUserAuthRequestParams
  | IUserLogoutRequestParams
  | IUserProfileRequestParams
  | ITransformerListRequestParams
  | ITransformerResolveRequestParams
  | ITransformerSaveRequestParams

export type IRequestPayload =
  | IFileSaveRequestPayload
  | IWhiteboardCreateRequestPayload
  | IUserAuthRequestPayload
  | IUserLogoutRequestPayload
  | IUserProfileRequestPayload
  | ITransformerListRequestPayload
  | ITransformerResolveRequestPayload
  | ITransformerSaveRequestPayload

export type IResponseResult =
  | IFileSaveResponseResult
  | IUserAuthResponseResult
  | IUserLogoutResponseResult
  | IUserProfileResponseResult
  | ITransformerListResponseResult
  | ITransformerResolveResponseResult
  | ITransformerSaveResponseResult
