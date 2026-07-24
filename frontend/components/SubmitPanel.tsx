"use client";

import {useEffect, useRef, useState} from "react";
// import {signOut} from "aws-amplify/auth";
import {LICENSE_FIELDS, type LicenseDetails, type StatusResponse} from "@/lib/types";
import { requestUploadUrl, uploadZip, fetchStatus} from "@/lib/api";
import {buildSubmissionZip} from "@/lib/zip";
import {DobPicker} from "@/components/DobPicker";
import {devNull} from "node:os";

// import Props {
//     onSignOut: () => void;
// }

//Realistic Mock data
const MOCK: LicenseDetails = {
  DOCUMENT_NUMBER: "S123-4567-8901",
  FIRST_NAME: "Giancarlo",
  LAST_NAME: "Martinez",
  // DATE_OF_BIRTH: "2025-15-21",
  DATE_OF_BIRTH: "",
  ADDRESS: "742 Evergreen Terrace",
  STATE_IN_ADDRESS: "CA",
  CITY_IN_ADDRESS: "Springfield",
  ZIP_CODE_IN_ADDRESS: "90210",
};

export default function SubmitPanel(){
  const [details, setDetails] = useState<LicenseDetails>(MOCK);
  const [license, setLicense] = useState<File | null>(null);
  const [selfie, setSelfie] = useState<File | null>(null);
  const [uuid, setUuid] = useState<string | null>(null);
  const [status, setStatus] = useState<StatusResponse | null>(null);
  // const [status, setStatus] = useState<StatusResponse | null>({status: "done", LICENSE_SELFIE_MATCH: true, LICENSE_VALIDATION:false, LICENSE_DETAILS_MATCH:null});
  const [error, setError] = useState<string |null>(null);
  const [busy, setBusy] = useState(false);

  // holds timer's ID, without causing component to re-render when it changes
  //setInterval() starta a timer that gives bacjk ID so you can stop it later with clearInterval(id)
  //useRef(null) is empty box to store timer ID, survives across re renders
  const timer = useRef<ReturnType<typeof setInterval> | null>(null);

  //useEffect => "when to do something"
  // Poll GET /api/status while having a uuid and it is still pending
  useEffect(() => {
    if (!uuid) return; // no uuid? don't start polling (nothing uploaded yet)
    let attempts = 0;
    timer.current = setInterval(async () => { //every time timer fires, +1 attempt
      attempts += 1;
      try {
        const s = await fetchStatus(uuid); //ask backend status of uuid, save the answer so UI can see it
        setStatus(s);
        //Stop when done or give up after ~2 min. If not it polls forever
        // stop once is "done" or it tried for over 40 times
        if ((s.status === "done" || attempts >= 40) && timer.current){
          clearInterval(timer.current);
          if (s.status !== "done") //if stopped because it gave up, show error message
            setError("Still processing - check back later or contact support.");
        }
      }catch (e){ //show error of why it actually stopped
        setError(e instanceof Error ? e.message : String(e));
      }
    }, 3000); //return the polling function every 3,000ms (3 sec)
    return () => { //cleanup func
      if (timer.current) clearInterval(timer.current); //before setting up new timer, stop old timer first so it does not run in the background
    };
  }, [uuid]); //effect runs whenever uuid changes
  // uuid starts null, when user uploads file, app gets back real uuid and changes from null -> str.
  //  since the dependency changed, re runs the effect which kicks off the polling loop for that specific upload
  //  if it changed later, it will re run new polling loop

  async function handleSubmit(){
    if (!license || !selfie){
      setError("Pick both a license image and a selfie.");
      return;
    }
    setError(null);
    setBusy(true);
    setStatus(null);
    try{
      //  export interface UploadUrlResponse {uuid: string;url: string;key: string;}
      const {uuid: id, url} = await requestUploadUrl();//1) presigned URL
      const zip = await buildSubmissionZip(id, details, license, selfie); //2) zip
      await uploadZip(url, zip) //3) PUT to S3 -> fires the pipeline
      setUuid(id); // 4) start polling (via the effect above)
    }catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  }



  return(<>
    <div className={"mx-auto mt-10 w-full max-w-2xl px-4"}>
      <header className={"mb-6 flex items-center justify-between"}>
        <h1 className={"text-2xl font-semibold"}>Submit your license</h1>
        <button
          // onClick={() => signOut().then(onSignOut)}
          className={"text-sm text-slate-500 underline hover:text-slate-800"}
        >
          Sign Out
        </button>

      </header>

      <div className={"rounded-xl border border-slate-200 bg-white p-6 shadow-sm"}>
        {/*Detail fields (filled with mock data)*/}
        <div className={"grid grid-cols-1 gap-3 sm:grid-cols-2"}>
          {LICENSE_FIELDS.filter((field) => field !== "DATE_OF_BIRTH").map((field) => (
            <label key={field} className={"text-sm"}>
              <span className={"mb-1 block font-medium text-slate-600"}>{field.replaceAll("_"," ").toLowerCase()}</span>
              <input
                value={details[field]}
                onChange={(e) => setDetails({...details, [field]:e.target.value})}
                className={"w-full rounded-md border border-slate-300 px-3 py-2 focus:border-blue-500  focus:outline-none"}
              />
            </label>
        ))}

          <label className={"text-sm"}>
            <span className={"mb-1 block font-medium text-slate-600"}>date of birth</span>
            <DobPicker
              value={details.DATE_OF_BIRTH}
              onChange={(v) => setDetails({...details, DATE_OF_BIRTH: v})}
            />
          </label>

        </div>

        {/*Image Pickers*/}
        <div className={"mt-5 grid grid-cols-1 gap-4 sm:grid-cols-2"}>
          <FilePick label={"License image"} onPick={setLicense} file={license}/>
          <FilePick label={"Selfie"} onPick={setSelfie} file={selfie}/>
        </div>

        {
          error && (
              <p className={"mt-4 rounded-md bg-red-50 px-3 py-2 text-sm text-red-700"}>{error}</p>
            )
        }

        <button
          onClick={handleSubmit}
          disabled={busy}
          className={"mt-5 w-full bg-blue-600 rounded-md px-4 py-2.5 font-medium text-white hover:bg-blue-700 disabled:opacity-50"}
        >
          {busy ? "Uploading...": `Submit for verification`}
        </button>
      </div>

      {/*Results*/}
      {uuid && (
       //{(
          <div className={"mt-6 rounded-xl border border-slate-200 bg-white p-6 shadow-sm"}>
            <div className={"mb-3 flex items-center justify-between"}>
              <h2 className={"text-lg font-semibold"}>Result</h2>
              <span className={"font-mono text-xs text-slate-400"}>id: {uuid}</span>
            </div>

            {!status || status.status == "pending" ? (
                <p className={"animate-pulse text-slate-500"}> Processing... Checking every 3s.</p>
            ):
                (
                    <div className={"space-y-2"}>
                      <Flag label={"Face match (selfie vs license)"} value={status.LICENSE_SELFIE_MATCH}></Flag>
                      <Flag label={"Details match (form vs license)"} value={status.LICENSE_DETAILS_MATCH}></Flag>
                      <Flag label={"License validated"} value={status.LICENSE_VALIDATION}></Flag>
                    </div>

                )}
          </div>

      )}

      {/*<DobPicker*/}
      {/*  value={details.DATE_OF_BIRTH}*/}
      {/*  onChange={(v) => setDetails({...details, DATE_OF_BIRTH: v})}*/}
      {/*/>*/}
    </div>

  </>);
}

function FilePick({label, file, onPick}: {label:string; file: File | null; onPick: (f:File) => void;}){
    return(
        <label className={"flex cursor-pointer flex-col items-center justify-center rounded-md border-2 border-dashed border-slate-300 p-4 text-center hover:border-blue-400"}>
          <span className={"text-sm font-medium text-slate-600"}>{label}</span>
          {/*<span className={"text-sm font-medium text-slate-600"}>{label}</span>*/}
          <span className={"mt-1 mb-1 text-xs text-slate-400"}>{file ? file.name : `Click to choose`}</span>
          <input
            type={"file"}
            accept={"image/*"}
            className={"hidden"}
            onChange={(e) => e.target.files?.[0] && onPick(e.target.files[0])}
          />
        </label>
    )
}


// '?' prop might be ommited if parent didn't pass it.
// false = check ran and it failed
function Flag({label, value}:{label:string, value?: boolean | string | null}){ //matches LICENSE_SELFIE_MATCH?: boolean | string | null
  //false === true => false
  const passed = value === true || value ==="true"; //if there was a result, was it good news?

  //false === true || false === false ... => true
  const hasResult = value === true || value === false || value === "true" || value ==="false"; // should I even look at pass/fail? Is there an answer at all?


  const color = !hasResult ?
      "bg-slate-100 text-slate-500" //if no result
      : passed ? // if there is result
       "bg-green-100 text-green-700" //and it passed = true => green
      :  "bg-red-100 text-red-700"; // if there is a result and it did not pass, result existed but failed -> red
  const text = !hasResult ? "pending": passed? "PASS":"FAIL"; //if there is no resultColor = pending, else if passed is Pass and if not fail
  return(
    <div className="flex items-center justify-between">
      <span className="text-sm text-slate-700">{label}</span>
      <span className={`rounded-full px-2.5 py-0.5 text-xs font-semibold ${color}`}>{text}</span>
    </div>
  );
}