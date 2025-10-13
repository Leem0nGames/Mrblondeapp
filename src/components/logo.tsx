
"use client";

import { cn } from "@/lib/utils";
import { Package } from "lucide-react";

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
      <Package className={cn("h-6 w-6", textColor)} />
      {showText && <span className={cn(textColor, isMono && "font-sans font-extrabold tracking-tighter")}>{textContent}</span>}
    </div>
  );
}
