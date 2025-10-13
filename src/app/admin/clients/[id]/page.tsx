

import Link from "next/link";
import { ArrowLeft, FileWarning } from "lucide-react";
import { getClientById, getClientStats, getClientOrders } from "@/app/actions/admin.actions";
import { Button } from "@/components/ui/button";
import { ClientHeader } from "./_components/client-header";
import { ClientInfo } from "./_components/client-info";
import { ClientStats } from "./_components/client-stats";
import { ClientOrders } from "./_components/client-orders";
import { ShippingLabel } from "./_components/shipping-label";

export default async function ClientDetailPage({
  params,
}: {
  params: { id: string };
}) {
  const clientResult = await getClientById(params.id);
  const statsResult = await getClientStats(params.id);
  const ordersResult = await getClientOrders(params.id);

  if (clientResult.error || !clientResult.data) {
    return (
      <div className="flex flex-1 items-center justify-center rounded-lg border border-dashed shadow-sm">
        <div className="flex flex-col items-center gap-1 text-center">
          <FileWarning className="w-12 h-12 text-muted-foreground" />
          <h3 className="text-2xl font-bold tracking-tight">
            Cliente no encontrado
          </h3>
          <p className="text-sm text-muted-foreground">
            No se pudo encontrar el cliente solicitado o ocurrió un error.
          </p>
          <Button asChild className="mt-4">
            <Link href="/admin/clients">Volver a Clientes</Link>
          </Button>
        </div>
      </div>
    );
  }
  
  const client = clientResult.data;
  const stats = statsResult.data;
  const orders = ordersResult;

  return (
    <div className="grid flex-1 items-start gap-4 md:gap-8">
        <div className="flex items-center gap-4">
            <Button variant="outline" size="icon" className="h-7 w-7" asChild>
            <Link href="/admin/clients">
                <ArrowLeft className="h-4 w-4" />
                <span className="sr-only">Volver</span>
            </Link>
            </Button>
             <h1 className="text-xl font-semibold tracking-tight sm:hidden">
                {client.contact_name}
            </h1>
        </div>

        <div>
            <ClientHeader client={client} />
        </div>

        {stats && <div><ClientStats stats={stats} /></div>}

        <div className="grid gap-4 md:grid-cols-3 md:gap-8">
            <div className="md:col-span-2">
                <ClientOrders orders={orders} />
            </div>
            <div className="md:col-span-1 grid gap-4 auto-rows-min">
                <div>
                    <ShippingLabel client={client} />
                </div>
                <div>
                    <ClientInfo client={client} />
                </div>
            </div>
        </div>
    </div>
  );
}
