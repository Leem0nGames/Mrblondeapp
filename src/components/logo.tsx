
"use client";

import { cn } from "@/lib/utils";

export function Logo({
  className,
  showText = false,
  isMono = false,
}: {
  className?: string;
  showText?: boolean;
  isMono?: boolean;
}) {
  const textColor = isMono ? "text-black" : "text-primary";
  const textContent = isMono ? "MR. BLONDE" : "Blonde Orders";
  return (
    <div
      className={cn(
        "flex items-center gap-2 text-lg font-bold font-headline",
        className
      )}
    >
      {!isMono && <span className="font-extrabold tracking-tighter text-2xl">MR.</span>}
      <span className={cn("font-extrabold tracking-tighter", isMono ? "text-black" : "text-primary", showText ? "text-2xl" : "text-lg")}>
        BLONDE
      </span>
    </div>
  );
}
