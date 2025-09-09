import Link from "next/link";
import { cn } from "@/lib/utils";
import { Package } from "lucide-react";

export function Logo({ className }: { className?: string }) {
  return (
    <Link
      href="/"
      className={cn(
        "flex items-center gap-2 text-lg font-bold font-headline text-primary",
        className
      )}
    >
      <Package className="h-6 w-6" />
      <span>Blonde Orders</span>
    </Link>
  );
}
