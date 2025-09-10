import { cn } from "@/lib/utils";
import { Package } from "lucide-react";

export function Logo({
  className,
  showText = false,
}: {
  className?: string;
  showText?: boolean;
}) {
  return (
    <div
      className={cn(
        "flex items-center gap-2 text-lg font-bold font-headline",
        className
      )}
    >
      <Package className="h-6 w-6 text-primary" />
      {showText && <span className="text-primary">Blonde Orders</span>}
    </div>
  );
}
