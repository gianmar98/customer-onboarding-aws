// Renders a passport-style MRZ from the submission id + applicant name.
export default function MrzStrip({ id, name }: { id: string; name: string }) {
  const parts = name.trim().split(/\s+/); //trim() removes outer spaces; split(...) splits any run of whitespace -["Giancarlo","Martinez"]
  const surname = (parts.at(-1) ?? "APPLICANT").toUpperCase();// at -1 grabs last name. if missing use APPLICANT instead
  const given = (parts[0] ?? "").toUpperCase();//at [0] get the first name
  const pad = (s: string) => s.padEnd(30, "<").slice(0, 30);// force every lien to be exactly 30 characters
  const line1 = pad(`VERIF<${surname}<<${given}`); //<VERIF<MARTINEZ<<GIANCARLO<<<
  const line2 = pad(`${id.toUpperCase()}<<<`); // TEST-UUID-123<<<<<
  return (
    <div className="mt-4 overflow-x-auto rounded-md bg-ink px-3 py-2 font-mono text-[11px] leading-5 tracking-[0.25em] text-paper">
      <div>{line1}</div>
      <div>{line2}</div>
    </div>
  );
}
