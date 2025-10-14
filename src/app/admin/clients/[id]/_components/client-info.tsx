
"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import type { Client } from "@/types";
import { AssignAgreementDialog } from "../../_components/assign-agreement-dialog";
import Link from "next/link";
import { Edit } from "lucide-react";
import { OnboardingFormDialog } from "./onboarding-form-dialog";

export function ClientInfo({ client }: { client: Client }) {

    const statusMap: Record<Client['status'], { label: string; variant: "default" | "secondary" | "destructive" | "outline" }> = {
        pending_onboarding: { label: "Pendiente de Alta", variant: "secondary" },
        pending_agreement: { label: "Pendiente de Convenio", variant: "destructive" },
        active: { label: "Activo", variant: "default" },
        archived: { label: "Archivado", variant: "outline" },
    };


  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between">
        <CardTitle>Datos del Cliente</CardTitle>
        <OnboardingFormDialog client={client}>
            <Button variant="outline" size="icon" className="h-8 w-8">
                <Edit className="h-4 w-4" />
            </Button>
        </OnboardingFormDialog>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="space-y-1 text-sm">
            <p className="font-medium">Estado</p>
            <div><Badge variant={statusMap[client.status].variant}>{statusMap[client.status].label}</Badge></div>
        </div>
         <div className="space-y-1 text-sm">
          <p className="font-medium">Email</p>
          <p className="text-muted-foreground">{client.email ?? "No especificado"}</p>
        </div>
        <div className="space-y-1 text-sm">
          <p className="font-medium">Convenio Asignado</p>
          <div className="flex items-center gap-2">
            {client.agreements ? (
              <Button variant="link" asChild className="p-0 h-auto font-semibold">
                <Link href={`/admin/agreements/${client.agreement_id}`}>{client.agreements.agreement_name}</Link>
              </Button>
            ) : (
              <p className="text-muted-foreground">Ninguno</p>
            )}
             <AssignAgreementDialog client={client}>
                <Button variant="outline" size="sm" className="h-7 text-xs">Cambiar</Button>
             </AssignAgreementDialog>
          </div>
        </div>
        <div className="space-y-1 text-sm">
          <p className="font-medium">Dirección de Entrega</p>
          <p className="text-muted-foreground">{client.address ?? "No especificada"}</p>
        </div>
        <div className="space-y-1 text-sm">
          <p className="font-medium">Ventana de Entrega</p>
          <p className="text-muted-foreground">{client.delivery_window ?? "No especificada"}</p>
        </div>
        <div className="space-y-1 text-sm">
          <p className="font-medium">Instagram</p>
          <p className="text-muted-foreground">{client.instagram ?? "No especificado"}</p>
        </div>
      </CardContent>
    </Card>
  );
}
