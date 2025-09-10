import Link from "next/link";
import {
  Package,
  Users,
  Percent,
  LogOut,
  Home,
  Link2,
  FileText
} from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { Logo } from "@/components/logo";
import { logout } from "@/app/actions/user.actions";

export default function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="flex min-h-screen w-full flex-col bg-background">
      <aside className="fixed inset-y-0 left-0 z-10 hidden w-14 flex-col border-r bg-muted/40 sm:flex">
        <nav className="flex flex-col items-center gap-4 px-2 sm:py-5">
          <Logo className="group flex h-9 w-9 shrink-0 items-center justify-center gap-2 rounded-full bg-primary text-lg font-semibold text-primary-foreground md:h-8 md:w-8 md:text-base" />
          <TooltipProvider>
             <Tooltip>
              <TooltipTrigger asChild>
                <Link
                  href="/admin"
                  className="flex h-9 w-9 items-center justify-center rounded-lg text-muted-foreground transition-colors hover:text-foreground md:h-8 md:w-8"
                >
                  <Home className="h-5 w-5" />
                  <span className="sr-only">Dashboard</span>
                </Link>
              </TooltipTrigger>
              <TooltipContent side="right">Dashboard</TooltipContent>
            </Tooltip>
            <Tooltip>
              <TooltipTrigger asChild>
                <Link
                  href="/admin/products"
                  className="flex h-9 w-9 items-center justify-center rounded-lg text-muted-foreground transition-colors hover:text-foreground md:h-8 md:w-8"
                >
                  <Package className="h-5 w-5" />
                  <span className="sr-only">Products</span>
                </Link>
              </TooltipTrigger>
              <TooltipContent side="right">Products</TooltipContent>
            </Tooltip>
             <Tooltip>
              <TooltipTrigger asChild>
                <Link
                  href="/admin/agreements"
                  className="flex h-9 w-9 items-center justify-center rounded-lg text-muted-foreground transition-colors hover:text-foreground md:h-8 md:w-8"
                >
                  <FileText className="h-5 w-5" />
                  <span className="sr-only">Agreements</span>
                </Link>
              </TooltipTrigger>
              <TooltipContent side="right">Agreements</TooltipContent>
            </Tooltip>
            <Tooltip>
              <TooltipTrigger asChild>
                <Link
                  href="/admin/clients"
                  className="flex h-9 w-9 items-center justify-center rounded-lg text-muted-foreground transition-colors hover:text-foreground md:h-8 md:w-8"
                >
                  <Users className="h-5 w-5" />
                  <span className="sr-only">Clients</span>
                </Link>
              </TooltipTrigger>
              <TooltipContent side="right">Clients</TooltipContent>
            </Tooltip>
            <Tooltip>
              <TooltipTrigger asChild>
                <Link
                  href="/admin/promotions"
                  className="flex h-9 w-9 items-center justify-center rounded-lg text-muted-foreground transition-colors hover:text-foreground md:h-8 md:w-8"
                >
                  <Percent className="h-5 w-5" />
                  <span className="sr-only">Promotions</span>
                </Link>
              </TooltipTrigger>
              <TooltipContent side="right">Promotions</TooltipContent>
            </Tooltip>
             <Tooltip>
              <TooltipTrigger asChild>
                <Link
                  href="/admin/links"
                  className="flex h-9 w-9 items-center justify-center rounded-lg text-muted-foreground transition-colors hover:text-foreground md:h-8 md:w-8"
                >
                  <Link2 className="h-5 w-5" />
                  <span className="sr-only">Links</span>
                </Link>
              </TooltipTrigger>
              <TooltipContent side="right">Links</TooltipContent>
            </Tooltip>
          </TooltipProvider>
        </nav>
        <nav className="mt-auto flex flex-col items-center gap-4 px-2 sm:py-5">
          <TooltipProvider>
            <Tooltip>
              <TooltipTrigger asChild>
                <form action={logout}>
                  <Button
                    variant="ghost"
                    size="icon"
                    className="flex h-9 w-9 items-center justify-center rounded-lg text-muted-foreground transition-colors hover:text-foreground md:h-8 md:w-8"
                  >
                    <LogOut className="h-5 w-5" />
                    <span className="sr-only">Logout</span>
                  </Button>
                </form>
              </TooltipTrigger>
              <TooltipContent side="right">Logout</TooltipContent>
            </Tooltip>
          </TooltipProvider>
        </nav>
      </aside>
      <div className="flex flex-col sm:gap-4 sm:py-4 sm:pl-14">
        <header className="sticky top-0 z-30 flex h-14 items-center gap-4 border-b bg-background px-4 sm:static sm:h-auto sm:border-0 sm:bg-transparent sm:px-6">
            <div className="sm:hidden">
              <Logo />
            </div>
             <div className="ml-auto sm:hidden">
                 <form action={logout}>
                  <Button
                    variant="ghost"
                    size="icon"
                  >
                    <LogOut className="h-5 w-5" />
                    <span className="sr-only">Logout</span>
                  </Button>
                </form>
            </div>
        </header>
        <main className="grid flex-1 items-start gap-4 p-4 sm:px-6 sm:py-0 md:gap-8 pb-20 sm:pb-4">
            {children}
        </main>
      </div>
       <footer className="sm:hidden fixed bottom-0 left-0 right-0 h-16 bg-background border-t z-10">
        <nav className="h-full">
          <ul className="h-full flex justify-around items-center">
            <li>
                <Link
                  href="/admin"
                  className="flex flex-col items-center text-muted-foreground hover:text-foreground"
                >
                  <Home className="h-6 w-6" />
                  <span className="text-xs">Home</span>
                </Link>
            </li>
            <li>
                <Link
                  href="/admin/products"
                  className="flex flex-col items-center text-muted-foreground hover:text-foreground"
                >
                  <Package className="h-6 w-6" />
                  <span className="text-xs">Products</span>
                </Link>
            </li>
             <li>
                <Link
                  href="/admin/clients"
                  className="flex flex-col items-center text-muted-foreground hover:text-foreground"
                >
                  <Users className="h-6 w-6" />
                  <span className="text-xs">Clients</span>
                </Link>
            </li>
            <li>
                <Link
                  href="/admin/agreements"
                  className="flex flex-col items-center text-muted-foreground hover:text-foreground"
                >
                  <FileText className="h-6 w-6" />
                  <span className="text-xs">Agreements</span>
                </Link>
            </li>
             <li>
                <Link
                  href="/admin/promotions"
                  className="flex flex-col items-center text-muted-foreground hover:text-foreground"
                >
                  <Percent className="h-6 w-6" />
                  <span className="text-xs">Promos</span>
                </Link>
            </li>
             <li>
                <Link
                  href="/admin/links"
                  className="flex flex-col items-center text-muted-foreground hover:text-foreground"
                >
                  <Link2 className="h-6 w-6" />
                  <span className="text-xs">Links</span>
                </Link>
            </li>
          </ul>
        </nav>
      </footer>
    </div>
  );
}
