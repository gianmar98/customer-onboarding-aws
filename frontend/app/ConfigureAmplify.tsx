"use client";

import {Amplify} from "aws-amplify";
import {amplifyConfig} from "@/app/amplify-config";

// Runs as soon as module is on the browser
Amplify.configure(amplifyConfig)

// Renders nothing - it exists onlny for its side effect (configuring Amplify)
export default function ConfigureAmplify(){
    return null
}