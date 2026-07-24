"use client"

import React, { useState} from "react";
import {format, parse} from "date-fns";
import {Calendar} from "@/components/ui/calendar";
import {Popover, PopoverContent, PopoverTrigger} from "@/components/ui/popover";
import {Button} from "@/components/ui/button";
import {ChevronDownIcon} from "lucide-react";

export function DobPicker({value,onChange}:{value:string, onChange: (v:string)=> void;}){
    const [open, setOpen] = useState(false);
  const date = value ? parse(value, "yyyy-MM-dd", new Date()) : undefined;
  return (
    <Popover>
      <PopoverTrigger render={<Button variant={"outline"} data-empty={!date} className="w-[212px] justify-between text-left font-normal data-[empty=true]:text-muted-foreground">
          {date ? format(date, "PPP") : <span>Pick a date</span>}
          <ChevronDownIcon data-icon="inline-end" />
      </Button>} />
      <PopoverContent className="w-auto p-0" align="start">
        <Calendar
          mode="single"
          selected={date}
          onSelect={(d) => {
              if (d) onChange(format(d,"yyyy-MM-dd"));
              setOpen(false)
          }}
          defaultMonth={date}
        />
      </PopoverContent>
    </Popover>
  )
}
