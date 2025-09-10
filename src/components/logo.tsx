"use client";

import { useState, useEffect } from 'react';
import { cn } from "@/lib/utils";
import { Package } from "lucide-react";

export function Logo({
  className,
  showText: initialShowText = false, // Renamed to avoid conflict
}: {
  className?: string;
  showText?: boolean;
}) {
  const [isClient, setIsClient] = useState(false);

  useEffect(() => {
    setIsClient(true);
  }, []);

  return (
    <div
      className={cn(
        "flex items-center gap-2 text-lg font-bold font-headline",
        className
      )}
    >
      <Package className="h-6 w-6 text-primary" />
      {initialShowText && isClient && <span className="text-primary">Blonde Orders</span>}
    </div>
  );
}
