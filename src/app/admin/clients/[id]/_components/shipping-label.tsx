
"use client";

import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import type { Client } from "@/types";
import { Printer, User, MapPin, Clock } from "lucide-react";
import { Separator } from "@/components/ui/separator";
import { Logo } from "@/components/logo";

export function ShippingLabel({ client }: { client: Client }) {
    
    const handlePrint = () => {
        window.print();
    }

  return (
    <Card id="shipping-label-card" className="print-content">
      <CardHeader>
        <div className="flex justify-between items-start">
            <div>
                <CardTitle>Rótulo de Envío</CardTitle>
                <CardDescription>Para el paquete del cliente.</CardDescription>
            </div>
            <div className="print-hide">
                 <Logo />
            </div>
        </div>
      </CardHeader>
      <CardContent className="space-y-4 text-sm">
        <Separator />
        <div className="space-y-1 pt-2">
            <p className="font-semibold text-muted-foreground">DESTINATARIO</p>
            <p className="text-lg font-bold text-foreground">{client.contact_name || "Nombre no especificado"}</p>
        </div>
         <Separator />
         <div className="space-y-1">
            <p className="font-semibold text-muted-foreground">DIRECCIÓN DE ENTREGA</p>
            <p className="text-foreground">{client.address || "Dirección no especificada"}</p>
        </div>
         <Separator />
         <div className="space-y-1">
            <p className="font-semibold text-muted-foreground">VENTANA HORARIA</p>
            <p className="text-foreground">{client.delivery_window || "Horario no especificado"}</p>
        </div>
         <Separator />
         <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1">
                <p className="font-semibold text-muted-foreground">CUIT</p>
                <p className="text-foreground">{client.cuit || "N/A"}</p>
            </div>
            <div className="space-y-1">
                <p className="font-semibold text-muted-foreground">DNI</p>
                <p className="text-foreground">{client.contact_dni || "N/A"}</p>
            </div>
         </div>
      </CardContent>
      <CardFooter className="no-print">
        <Button onClick={handlePrint} className="w-full">
            <Printer className="mr-2 h-4 w-4" />
            Imprimir Rótulo
        </Button>
      </CardFooter>
    </Card>
  );
}
