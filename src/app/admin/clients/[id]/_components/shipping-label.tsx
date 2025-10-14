
"use client";

import { useState, useEffect } from "react";
import { usePDF } from "@react-pdf/renderer";
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import type { Client } from "@/types";
import { Printer, Loader2 } from "lucide-react";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { ShippingLabelPDF } from "./shipping-label-pdf";

export function ShippingLabel({ client }: { client: Client }) {
  const [packageCount, setPackageCount] = useState(1);
  
  // El hook usePDF se inicializa con el componente del documento.
  const [instance, updateInstance] = usePDF({
    document: <ShippingLabelPDF client={client} totalBultos={packageCount} />,
  });

  // Este efecto se asegura de que el PDF se regenere cada vez que cambia el número de bultos.
  useEffect(() => {
    updateInstance();
  }, [packageCount, client, updateInstance]);

  const handlePrint = () => {
    if (instance.url && !instance.loading) {
      // Abre el PDF en una nueva pestaña
      const printWindow = window.open(instance.url);
      // Espera a que cargue y luego llama a la función de impresión del navegador
      printWindow?.addEventListener('load', function() {
        printWindow.print();
      });
    }
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle>Imprimir Rótulo de Envío</CardTitle>
        <CardDescription>
          Genera e imprime los rótulos para los paquetes del cliente.
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="space-y-2">
          <Label htmlFor="package-info">Número de Bultos</Label>
          <Input 
            id="package-info"
            type="number"
            value={packageCount}
            onChange={(e) => setPackageCount(Math.max(1, parseInt(e.target.value, 10)) || 1)}
            placeholder="Ej: 3"
            min="1"
          />
           <p className="text-xs text-muted-foreground">Define cuántos rótulos se imprimirán.</p>
        </div>
      </CardContent>
      <CardFooter>
        <Button 
          onClick={handlePrint} 
          disabled={instance.loading || !instance.url} 
          className="w-full"
        >
          {instance.loading ? (
            <>
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              Generando PDF...
            </>
          ) : (
            <>
              <Printer className="mr-2 h-4 w-4" />
              Imprimir Rótulos
            </>
          )}
        </Button>
      </CardFooter>
    </Card>
  );
}
