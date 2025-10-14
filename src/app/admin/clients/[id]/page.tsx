

import Link from "next/link";
import { ArrowLeft, FileWarning, Info, Landmark } from "lucide-react";
import { getAgreementById, getClientById, getClientStats, getClientOrders } from "@/app/actions/admin.actions";
import { Button } from "@/components/ui/button";
import { ClientHeader } from "./_components/client-header";
import { ClientInfo } from "./_components/client-info";
import { ClientStats } from "./_components/client-stats";
import { ClientOrders } from "./_components/client-orders";
import { ShippingLabel } from "./_components/shipping-label";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";

const formatRule = (rules: any): string => {
  if (!rules || typeof rules !== 'object') {
    return 'Regla no definida';
  }

  const { type, days, percentage, installments, initial_percentage, remaining_days } = rules;

  switch (type) {
    case 'net_days':
      return `Plazo de pago: ${days || 'N/D'} días netos.`;
    case 'discount':
      return `Descuento por pronto pago: ${percentage || 'N/D'}%.`;
    case 'installments':
        return `Financiación: ${installments || 'N/D'} cuotas.`;
    case 'split_payment':
        return `${initial_percentage || 'N/D'}% de adelanto, resto a ${remaining_days || 'N/D'} días.`;
    default:
      return 'Regla personalizada.';
  }
};

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
  const agreement = client.agreements;
  const stats = statsResult.data;
  const orders = ordersResult;

  const agreementDetails = agreement ? await getAgreementById(agreement.id) : null;
  const salesConditions = agreementDetails?.data?.agreement_sales_conditions ?? [];

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
        
        <Card className="bg-secondary/50">
            <CardHeader>
                <CardTitle className="flex items-center gap-2">
                    <Info className="h-5 w-5"/>
                    Información Clave
                </CardTitle>
                <CardDescription>Resumen de las condiciones fiscales y comerciales más importantes para este cliente.</CardDescription>
            </CardHeader>
            <CardContent className="grid gap-4 md:grid-cols-2">
                <div className="space-y-1 rounded-lg bg-background p-4">
                    <p className="text-sm font-medium text-muted-foreground">Condición Fiscal</p>
                    <p className="text-lg font-semibold">{client.fiscal_status || "No especificada"}</p>
                </div>
                 <div className="space-y-2 rounded-lg bg-background p-4">
                    <p className="text-sm font-medium text-muted-foreground">Condiciones de Venta (del Convenio)</p>
                     {salesConditions.length > 0 ? (
                        <ul className="space-y-2 text-sm">
                            {salesConditions.map(sc => (
                                <li key={sc.sales_conditions.id} className="flex items-center gap-2">
                                   <Landmark className="h-4 w-4 text-primary"/>
                                   <span className="font-medium">{sc.sales_conditions.name}:</span>
                                   <span className="text-muted-foreground">{formatRule(sc.sales_conditions.rules)}</span>
                                </li>
                            ))}
                        </ul>
                    ) : (
                        <p className="text-sm text-muted-foreground">No hay condiciones especiales asignadas.</p>
                    )}
                </div>
            </CardContent>
        </Card>

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
