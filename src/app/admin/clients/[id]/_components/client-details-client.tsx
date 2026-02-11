
"use client";

import Link from 'next/link';
import { useTransition, useCallback, useEffect, useState } from "react";
import { Info, Landmark, ArrowLeft, Edit, FilePen, Link as LinkIcon, MapPin } from "lucide-react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { ClientHeader } from "./client-header";
import { ClientInfo } from "./client-info";
import { ClientStats } from "./client-stats";
import { ClientOrders } from "./client-orders";
import { ClientAnalysis } from './client-analysis';
import { ClientMap } from '../../../_components/client-map';
import type { Client, ClientStats as StatsType, Order, AgreementSalesCondition } from "@/types";
import { Skeleton } from '@/components/ui/skeleton';
import { getAgreementSalesConditions } from "@/app/admin/actions/agreements.actions";
import { geocodeAddressAndSave } from "@/app/admin/actions/clients.actions";
import { useToast } from "@/hooks/use-toast";
import { AssignAgreementDialog } from '../../_components/assign-agreement-dialog';
import { ActionButton } from './client-action-buttons';
import { deleteClient } from '@/app/admin/actions/clients.actions';
import { UpsertClientDialog } from '../../_components/upsert-client-dialog';


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
}

export default function ClientDetailsClient({ client: initialClient, stats, orders }: ClientDetailsClientProps) {
  const { toast } = useToast();
  const [isPending, startTransition] = useTransition();
  const [isGeocoding, startGeocoding] = useTransition();
  const [client, setClient] = useState(initialClient);
  const [salesConditions, setSalesConditions] = useState<AgreementSalesCondition[]>([]);
  const [isLoadingConditions, setIsLoadingConditions] = useState(true);

  const [orderLink, setOrderLink] = useState<string | null>(null);

  useEffect(() => {
    if (typeof window !== 'undefined') {
      if (client.agreement_id && client.status === 'active') {
        setOrderLink(`${window.location.origin}/pedido/${client.agreement_id}`);
      } else {
        setOrderLink(null);
      }
    }
  }, [client.agreement_id, client.status]);
  
  useEffect(() => {
    setClient(initialClient);
  }, [initialClient]);

  useEffect(() => {
    if (client.address && !client.latitude) {
        startGeocoding(async () => {
            await geocodeAddressAndSave(client.id, client.address!);
            // The page will be revalidated, so we don't need to update state manually.
            toast({ title: 'Geocodificación', description: 'Dirección del cliente convertida a coordenadas.'})
        })
    }
  }, [client.id, client.address, client.latitude, toast]);

  useEffect(() => {
    if (client.agreement_id) {
      setIsLoadingConditions(true);
      getAgreementSalesConditions(client.agreement_id)
        .then(({ data, error }) => {
          if (error) {
            toast({ title: "Error", description: "No se pudieron cargar las condiciones de venta." });
          } else {
            setSalesConditions(data || []);
          }
        })
        .finally(() => setIsLoadingConditions(false));
    } else {
      setSalesConditions([]);
      setIsLoadingConditions(false);
    }
  }, [client.agreement_id, toast]);


  const copyToClipboard = useCallback((textToCopy: string | null, toastMessage: string, errorMessage?: string) => {
    if (!textToCopy) {
      toast({ title: "No hay nada para copiar", description: errorMessage || "El recurso no está disponible.", variant: "destructive"});
      return;
    }
    navigator.clipboard.writeText(textToCopy);
    toast({ title: toastMessage });
  }, [toast]);

  const handleArchive = () => {
    startTransition(async () => {
      const result = await deleteClient(client.id);
      if (result.error) {
        toast({ title: "Error", description: result.error.message, variant: "destructive" });
      } else {
        toast({ title: "Éxito", description: "Cliente archivado correctamente." });
      }
    });
  };

  const editDialog = (
    <UpsertClientDialog client={client}>
      <ActionButton>
        <Edit className="h-6 w-6" />
        <span>Editar Datos</span>
      </ActionButton>
    </UpsertClientDialog>
  );

  const agreementDialog = (
    <AssignAgreementDialog client={client}>
      <ActionButton>
        <FilePen className="h-6 w-6" />
        <span>Convenio</span>
      </ActionButton>
    </AssignAgreementDialog>
  );

  return (
    <>
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

      <ClientHeader 
        client={client}
        onArchive={handleArchive}
        isArchiving={isPending}
        onCopyLink={copyToClipboard}
        orderLink={orderLink}
        editDialog={editDialog}
        agreementDialog={agreementDialog}
      />

      {stats && <div><ClientStats stats={stats} /></div>}

      <div className="grid gap-4 md:grid-cols-3 md:gap-8">
          <div className="md:col-span-2 grid gap-4 auto-rows-min">
              <ClientAnalysis clientId={client.id} />
              <ClientOrders orders={orders} />
          </div>
          <div className="md:col-span-1 grid gap-4 auto-rows-min">
              <ClientInfo client={client} onCopy={copyToClipboard} />
              
               <Card>
                  <CardHeader>
                      <CardTitle className="flex items-center gap-2"><MapPin className="h-5 w-5"/> Ubicación</CardTitle>
                      <CardDescription>Mapa interactivo de la ubicación del cliente.</CardDescription>
                  </CardHeader>
                  <CardContent className="p-0">
                      {client.address && client.latitude && client.longitude ? (
                        <ClientMap
                          clients={[client]}
                          zoom={14}
                          center={{ lat: client.latitude, lng: client.longitude }}
                          mapId={`client-map-${client.id}`}
                          height="250px"
                        />
                      ) : (
                        <div className="h-[250px] flex items-center justify-center text-center p-4">
                            {isGeocoding ? (
                                <p className="text-sm text-muted-foreground animate-pulse">Geocodificando dirección...</p>
                            ) : (
                                <p className="text-sm text-muted-foreground">No hay una dirección válida o geocodificada para mostrar en el mapa.</p>
                            )}
                        </div>
                      )}
                  </CardContent>
              </Card>

               <Card className="bg-secondary/50">
                  <CardHeader>
                      <CardTitle className="flex items-center gap-2">
                          <Info className="h-5 w-5"/>
                          Información Clave
                      </CardTitle>
                      <CardDescription>Resumen de las condiciones fiscales y comerciales.</CardDescription>
                  </CardHeader>
                  <CardContent className="grid gap-4">
                      <div className="space-y-1 rounded-lg bg-background p-4">
                          <p className="text-sm font-medium text-muted-foreground">Condición Fiscal</p>
                          <p className="text-lg font-semibold">{client.fiscal_status || "No especificada"}</p>
                      </div>
                      <div className="space-y-2 rounded-lg bg-background p-4">
                          <p className="text-sm font-medium text-muted-foreground">Condiciones de Venta (del Convenio)</p>
                          {isLoadingConditions ? <Skeleton className="h-8 w-3/4" /> : salesConditions.length > 0 ? (
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
          </div>
      </div>
    </>
  )
}
