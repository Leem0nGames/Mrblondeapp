
"use client";

import { cn } from "@/lib/utils";
import { Atom } from "lucide-react";
import Image from 'next/image';

export function Logo({
  className,
  showText = false,
  logoUrl
}: {
  className?: string;
  showText?: boolean;
  logoUrl?: string | null;
}) {
  const textStyle: React.CSSProperties = {
    filter: 'drop-shadow(1px 2px 1px hsl(41 47% 57% / 0.7))',
    color: '#FFFFFF'
  };

  const IconOrLogo = () => {
    if (logoUrl) {
      // Usamos un div contenedor para manejar el tamaño de forma flexible
      return (
        <div className="relative w-full h-full">
          <Image 
            src={logoUrl} 
            alt="App Logo" 
            fill 
            className="object-contain"
            priority
          />
        </div>
      );
    }
    return <Atom className="h-5 w-5" />;
  };

  if (showText) {
    return (
        <div
        className={cn(
            "flex items-center gap-2 text-lg font-bold font-headline",
            className
        )}
        >
            <div className="bg-primary text-primary-foreground p-1.5 rounded-md relative h-10 w-10 overflow-hidden flex items-center justify-center">
                <IconOrLogo />
            </div>
            <span style={textStyle} className={cn("font-extrabold tracking-tighter text-xl")}>
                MR. BLONDE
            </span>
        </div>
    );
  }

  return (
    <div
      className={cn(
        "relative flex items-center justify-center bg-primary text-primary-foreground rounded-lg h-full w-full overflow-hidden p-1",
        className
      )}
    >
      <IconOrLogo />
    </div>
  );
}
