

import Link from "next/link";
import { ArrowLeft, FileWarning, Info, Landmark } from "lucide-react";
import { getAgreementById, getClientById, getClientStats, getClientOrders } from "@/app/actions/admin.actions";
import { Button } from "@/components/ui/button";
import { ClientHeader } from "./_components/client-header";
import { ClientDetailsClient } from "./_components/client-details-client";


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
  const stats = statsResult.data;
  const orders = ordersResult;

  const agreementDetails = client.agreements ? await getAgreementById(client.agreements.id) : null;
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

        <ClientDetailsClient 
            client={client}
            stats={stats}
            orders={orders}
            salesConditions={salesConditions}
        />
    </div>
  );
}
