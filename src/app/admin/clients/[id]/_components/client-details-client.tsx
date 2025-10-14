
"use client";

import dynamic from 'next/dynamic';
import { Info, Landmark } from "lucide-react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { ClientHeader } from "./client-header";
import { ClientInfo } from "./client-info";
import { ClientStats } from "./client-stats";
import { ClientOrders } from "./client-orders";
import type { Client, ClientStats as StatsType, Order, AgreementSalesCondition } from "@/types";

const ShippingLabel = dynamic(
  () => import('./shipping-label').then(mod => mod.ShippingLabel),
  { 
    ssr: false,
    loading: () => <p className="text-sm text-muted-foreground p-4">Cargando generador de rótulos...</p> 
  }
);

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

type ClientDetailsClientProps = {
    client: Client;
    stats: StatsType | null;
    orders: Order[];
    salesConditions: AgreementSalesCondition[];
}

export function ClientDetailsClient({ client, stats, orders, salesConditions }: ClientDetailsClientProps) {
  return (
    <>
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
    </>
  )
}
