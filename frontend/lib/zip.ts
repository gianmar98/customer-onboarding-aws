import JSZip from "jszip";
import {LICENSE_FIELDS, type LicenseDetails} from "@/lib/types";


//ASSEMBLE EXACT FILE NAMES PIPELINE EXPECTS

// CSV-quote a value so commas in the address don't break columns to get proper CSV formatting
// if value has a " char, double it up (" => "") that is the CSV escaping rule for quotes
//      ex: cell('hello') => "hello"
const cell = (v: string) => `"${v.replace(/"/g, '""')}"`;

export async function buildSubmissionZip(
    uuid: string,
    details: LicenseDetails,
    licenseImage: File,
    selfieImage: File) : Promise<Blob> {
    const zip = new JSZip();

    //Header row + 1 data row, columns in the pipeline required order
    const header = LICENSE_FIELDS.join(","); //col names from license fields joined with commas

    //The actual values of each field, joined with commas
    const row = LICENSE_FIELDS.map((f)=> cell(details[f])).join(",");

    //Write as 2 line CSV: header row, then one data row
    zip.file(`${uuid}_details.csv`, `${header}\n${row}\n`);

    // Names MUST match the pipeline convention: <uuid>_license.png / <uuid>_selfie.png.
    // Rekognition/Textract detect the real format from bytes, so a .png name on a
    // JPEG is fine — the extension is just part of the S3 key.
    zip.file(`${uuid}_license.png`, licenseImage);
    zip.file(`${uuid}_selfie.png`, selfieImage);

    //return zip pacakge that can then be uploaded via PUT to zipped/<uuid>.zip in S3
    return zip.generateAsync({type:"blob"});

}