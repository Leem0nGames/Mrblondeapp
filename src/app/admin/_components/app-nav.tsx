
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
      <nav className="grid gap-6 text-base font-medium">
        {navItems.map((item) => {
          const isActive = pathname === item.href;
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                "flex items-center gap-4 px-2.5 text-muted-foreground hover:text-foreground",
                isActive && "text-foreground"
              )}
            >
              <item.icon className="h-5 w-5" />
              {item.label}
            </Link>
          );
        })}
      </nav>
    );
  }

  return (
    <TooltipProvider>
      <nav className="flex flex-col items-center gap-4 px-2 sm:py-5">
        {navItems.map((item) => {
          const isActive = pathname === item.href;
          return (
            <Tooltip key={item.href} delayDuration={0}>
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
      </nav>
    </TooltipProvider>
  );
}
