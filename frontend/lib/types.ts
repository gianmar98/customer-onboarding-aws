export const LICENSE_FIELDS = [
  "DOCUMENT_NUMBER",
  "FIRST_NAME",
  "LAST_NAME",
  "DATE_OF_BIRTH",
  "ADDRESS",
  "STATE_IN_ADDRESS",
  "CITY_IN_ADDRESS",
  "ZIP_CODE_IN_ADDRESS",
] as const;

// rule or label that tells the computer what kind of data is allowed to hold
// typeof LICENSE_FIELDS - 'one of the strings in LICENSE_FIELDS'
// [number] - "any item in it"
export type LicenseField = (typeof LICENSE_FIELDS)[number];

// Object with exact keys, all are str
// Records<Keys, ValueType> - doc who must have exactly those 8 keys
//          (DOCUMENT_NUMBER, FIRST_NAME, etc..) each mapped to an str value
//          EX: type LicenseDetails = {
//                   DOCUMENT_NUMBER: string;
//                   FIRST_NAME: string;
//                   ... all 8, by hand
//                  };
//
export type LicenseDetails = Record<LicenseField, string>;

// What GET /api/status returns. '?' = optional | 'null' = may be absent
export interface StatusResponse {
    status: "pending" | "done";
    LICENSE_SELFIE_MATCH?: boolean | string | null;
    LICENSE_DETAILS_MATCH?: boolean | string | null;
    LICENSE_VALIDATION?:boolean | string | null;
}

export interface UploadUrlResponse {
    uuid: string;
    url: string;
    key: string;
}