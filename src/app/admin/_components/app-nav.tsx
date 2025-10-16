
"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  Home,
  Package,
  Users,
  FileText,
  Percent,
  ClipboardList,
  Landmark,
} from "lucide-react";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { cn } from "@/lib/utils";

const navItems = [
  { href: "/admin", icon: Home, label: "Dashboard" },
  { href: "/admin/products", icon: Package, label: "Productos" },
  { href: "/admin/clients", icon: Users, label: "Clientes" },
  { href: "/admin/agreements", icon: FileText, label: "Convenios" },
  { href: "/admin/pricelists", icon: ClipboardList, label: "Listas de Precios" },
  { href: "/admin/promotions", icon: Percent, label: "Promociones" },
  { href: "/admin/sales-conditions", icon: Landmark, label: "Cond. de Venta" },
];

export function AppNav({ isMobile }: { isMobile: boolean }) {
  const pathname = usePathname();

  if (isMobile) {
    return (
      <div className="flex justify-around items-center h-full">
        {navItems.slice(0, 5).map((item) => { // Show first 5 for mobile bottom bar
          const isActive = pathname === item.href;
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                "flex flex-col items-center gap-1 text-muted-foreground transition-colors hover:text-foreground",
                isActive && "text-primary font-semibold"
              )}
            >
              <item.icon className="h-6 w-6" />
              <span className="text-xs">{item.label}</span>
            </Link>
          );
        })}
      </div>
    );
  }

  return (
    <TooltipProvider>
      {navItems.map((item) => {
        const isActive = pathname === item.href;
        return (
          <Tooltip key={item.href}>
            <TooltipTrigger asChild>
              <Link
                href={item.href}
                className={cn(
                  "flex h-9 w-9 items-center justify-center rounded-lg text-muted-foreground transition-colors hover:text-foreground md:h-8 md:w-8",
                  isActive && "bg-accent text-accent-foreground"
                )}
              >
                <item.icon className="h-5 w-5" />
                <span className="sr-only">{item.label}</span>
              </Link>
            </TooltipTrigger>
            <TooltipContent side="right">{item.label}</TooltipContent>
          </Tooltip>
        );
      })}
    </TooltipProvider>
  );
}
