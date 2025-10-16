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
import { cn } from "@/lib/utils";
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
import { Notifications } from "./_components/notifications";
import { getPendingOrders, getClientsWithPendingAgreements } from "@/app/actions/admin.actions";
import { AppNav } from "./_components/app-nav";
import type { Order, Client } from "@/types";

const formatCurrency = (value: number) => {
    return new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS' }).format(value);
}

const transformDataToNotifications = (orders: Order[], clients: Client[]) => {
    const orderNotifications = orders.map(order => ({
        id: `order-${order.id}`,
        type: 'order' as const,
        title: `Nuevo Pedido #${order.id.slice(-4)}`,
        description: `${order.client_name_cache} - ${formatCurrency(order.total_amount)}`,
        createdAt: new Date(order.created_at),
    }));

    const clientNotifications = clients.map(client => ({
        id: `client-${client.id}`,
        type: 'client' as const,
        title: "Cliente Pendiente",
        description: `${client.contact_name || 'Cliente'} completó el alta.`,
        createdAt: new Date(client.created_at),
    }));

    return [...orderNotifications, ...clientNotifications].sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
}


export default async function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const [pendingOrdersResult, pendingClientsResult] = await Promise.all([
    getPendingOrders(),
    getClientsWithPendingAgreements()
  ]);

  const notifications = transformDataToNotifications(
    pendingOrdersResult,
    pendingClientsResult
  );


  return (
    <div className="flex min-h-screen w-full flex-col bg-muted/40">
      <aside className="fixed inset-y-0 left-0 z-10 hidden w-16 flex-col border-r bg-background sm:flex">
        <nav className="flex flex-col items-center gap-4 px-2 py-4">
          <Link
            href="/admin"
            className="group flex h-10 w-10 shrink-0 items-center justify-center gap-2 rounded-full text-lg font-semibold text-primary-foreground"
          >
            <Logo />
            <span className="sr-only">Blonde Orders</span>
          </Link>
          <AppNav isMobile={false} />
        </nav>
        <nav className="mt-auto flex flex-col items-center gap-4 px-2 py-4">
          <TooltipProvider>
            <Tooltip>
              <TooltipTrigger asChild>
                <Link
                    href="/admin/settings"
                    className={cn(
                      "flex h-9 w-9 items-center justify-center rounded-lg text-muted-foreground transition-colors hover:text-foreground md:h-8 md:w-8"
                    )}
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
      <div className="flex flex-col sm:gap-4 sm:py-4 sm:pl-16">
        <header className="sticky top-0 z-30 flex h-14 items-center justify-between gap-4 border-b bg-background px-4 sm:static sm:h-auto sm:border-0 sm:bg-transparent sm:px-6">
            <div className="sm:hidden">
              <Link href="/admin">
                <Logo showText={true} />
              </Link>
            </div>
             <div className="ml-auto flex items-center gap-2">
                 <Notifications notifications={notifications} />
                 <Sheet>
                    <SheetTrigger asChild>
                    <Button
                        variant="outline"
                        size="icon"
                        className="shrink-0 sm:hidden"
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
                        <AppNav isMobile={true} />
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
         <AppNav isMobile={true} />
        </nav>
      </footer>
    </div>
  );
}
