
import Link from "next/link";
import { FileWarning, Printer } from "lucide-react";
import { getClientById, getClientStats, getClientOrders, getAgreementSalesConditions } from "@/app/actions/admin.actions";
import { Button } from "@/components/ui/button";
import { ClientDetailsClient } from "./_components/client-details-client";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import dynamic from "next/dynamic";

export default async function ClientDetailPage({
  params,
}: {
  params: { id: string };
}) {
  const [clientResult, statsResult, ordersResult] = await Promise.all([
    getClientById(params.id),
    getClientStats(params.id),
    getClientOrders(params.id)
  ]);

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
        <ClientDetailsClient 
            client={client}
            stats={stats}
            orders={orders}
        />
    </div>
  );
}

    