import Image from "next/image";
import SubmitPanel from "@/components/SubmitPanel";

export default function Home() {
  return (
    <div className="flex flex-col flex-1 items-center justify-center bg-zinc-50 font-sans dark:bg-black">
      <SubmitPanel/>
    </div>
  );
}
