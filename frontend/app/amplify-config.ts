import { type ResourcesConfig } from "aws-amplify";

export const amplifyConfig: ResourcesConfig = {
  Auth: {
    Cognito: {
      // The "!" is a TS "non-null assertion": it tells the compiler
      // "trust me, this env var is defined." If it's actually missing,
      // Amplify throws a clear error at runtime.
      userPoolId: process.env.NEXT_PUBLIC_USER_POOL_ID!,
      userPoolClientId: process.env.NEXT_PUBLIC_USER_POOL_CLIENT_ID!,
    },
  },
};