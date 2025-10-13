
import Link from "next/link";
import {
  Package,
  LogOut,
  FileText,
  Percent,
  Settings,
  Users,
  ClipboardList,
  Landmark,
  Home,
  Menu,
} from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { Sheet, SheetContent, SheetTrigger } from "@/components/ui/sheet";
import { Logo } from "@/components/logo";
import { logout } from "@/app/actions/user.actions";

const mainNavItems = [
    { href: "/admin", icon: Home, label: "Dashboard" },
    { href: "/admin/products", icon: Package, label: "Productos" },
    { href: "/admin/pricelists", icon: ClipboardList, label: "Precios" },
    { href: "/admin/agreements", icon: FileText, label: "Convenios" },
    { href: "/admin/clients", icon: Users, label: "Clientes" },
    { href: "/admin/promotions", icon: Percent, label: "Promos" },
    { href: "/admin/sales-conditions", icon: Landmark, label: "Condiciones" },
];

const mobileNavItems = [
    { href: "/admin/products", icon: Package, label: "Productos" },
    { href: "/admin/pricelists", icon: ClipboardList, label: "Precios" },
    { href: "/admin/agreements", icon: FileText, label: "Convenios" },
    { href: "/admin/clients", icon: Users, label: "Clientes" },
    { href: "/admin/promotions", icon: Percent, label: "Promos" },
    { href: "/admin", icon: Home, label: "Dashboard" },
]

export default function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="flex min-h-screen w-full flex-col bg-muted/40">
      <aside className="fixed inset-y-0 left-0 z-10 hidden w-14 flex-col border-r bg-background sm:flex">
        <nav className="flex flex-col items-center gap-4 px-2 sm:py-5">
          <Link
            href="/admin"
            className="group flex h-9 w-9 shrink-0 items-center justify-center gap-2 rounded-full bg-primary text-lg font-semibold text-primary-foreground md:h-8 md:w-8 md:text-base"
          >
            <Logo />
            <span className="sr-only">Blonde Orders</span>
          </Link>
          <TooltipProvider>
            {mainNavItems.map(item => (
                 <Tooltip key={item.href}>
                    <TooltipTrigger asChild>
                        <Link
                        href={item.href}
                        className="flex h-9 w-9 items-center justify-center rounded-lg text-muted-foreground transition-colors hover:text-foreground md:h-8 md:w-8"
                        >
                        <item.icon className="h-5 w-5" />
                        <span className="sr-only">{item.label}</span>
                        </Link>
                    </TooltipTrigger>
                    <TooltipContent side="right">{item.label}</TooltipContent>
                </Tooltip>
            ))}
          </TooltipProvider>
        </nav>
        <nav className="mt-auto flex flex-col items-center gap-4 px-2 sm:py-5">
          <TooltipProvider>
            <Tooltip>
              <TooltipTrigger asChild>
                <Link
                    href="/admin/settings"
                    className="flex h-9 w-9 items-center justify-center rounded-lg text-muted-foreground transition-colors hover:text-foreground md:h-8 md:w-8"
                    >
                    <Settings className="h-5 w-5" />
                    <span className="sr-only">Configuración</span>
                </Link>
              </TooltipTrigger>
              <TooltipContent side="right">Configuración</TooltipContent>
            </Tooltip>
            <Tooltip>
              <TooltipTrigger asChild>
                <form action={logout}>
                  <Button
                    variant="ghost"
                    size="icon"
                    className="flex h-9 w-9 items-center justify-center rounded-lg text-muted-foreground transition-colors hover:text-foreground md:h-8 md:w-8"
                  >
                    <LogOut className="h-5 w-5" />
                    <span className="sr-only">Cerrar Sesión</span>
                  </Button>
                </form>
              </TooltipTrigger>
              <TooltipContent side="right">Cerrar Sesión</TooltipContent>
            </Tooltip>
          </TooltipProvider>
        </nav>
      </aside>
      <div className="flex flex-col sm:gap-4 sm:py-4 sm:pl-14">
        <header className="sticky top-0 z-30 flex h-14 items-center justify-between gap-4 border-b bg-background px-4 sm:static sm:h-auto sm:border-0 sm:bg-transparent sm:px-6">
            <div className="sm:hidden">
              <Link href="/admin">
                <Logo showText={true} />
              </Link>
            </div>
             <div className="ml-auto sm:hidden">
                 <Sheet>
                    <SheetTrigger asChild>
                    <Button
                        variant="outline"
                        size="icon"
                        className="shrink-0"
                    >
                        <Menu className="h-5 w-5" />
                        <span className="sr-only">Toggle navigation menu</span>
                    </Button>
                    </SheetTrigger>
                    <SheetContent side="right">
                    <nav className="grid gap-6 text-lg font-medium">
                        <Link
                            href="/admin"
                            className="flex items-center gap-2 text-lg font-semibold mb-4"
                        >
                            <Logo showText={true} />
                            <span className="sr-only">Blonde Orders</span>
                        </Link>
                        {mainNavItems.map(item => (
                            <Link
                                key={item.href}
                                href={item.href}
                                className="text-muted-foreground hover:text-foreground"
                            >
                                {item.label}
                            </Link>
                        ))}
                         <Link
                            href="/admin/settings"
                            className="text-muted-foreground hover:text-foreground"
                         >
                            Configuración
                        </Link>
                         <form action={logout}>
                           <button className="w-full text-left text-muted-foreground hover:text-foreground">
                                Cerrar Sesión
                            </button>
                        </form>
                    </nav>
                    </SheetContent>
                </Sheet>
            </div>
        </header>
        <main className="grid flex-1 items-start gap-4 p-4 sm:px-6 sm:py-0 md:gap-8 pb-24 sm:pb-4">
            {children}
        </main>
      </div>
       <footer className="sm:hidden fixed bottom-0 left-0 right-0 h-16 bg-background border-t z-10">
        <nav className="h-full">
          <ul className="h-full grid grid-cols-6 justify-around items-center text-center">
            {mobileNavItems.map(item => (
                <li key={item.href}>
                    <Link
                        href={item.href}
                        className="flex flex-col items-center text-muted-foreground hover:text-primary"
                    >
                        <item.icon className="h-6 w-6" />
                        <span className="text-[10px]">{item.label}</span>
                    </Link>
                </li>
            ))}
          </ul>
        </nav>
      </footer>
    </div>
  );
}
