
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
  const [instance, updateInstance] = usePDF({
    document: <ShippingLabelPDF client={client} totalBultos={packageCount} />,
  });

  // Re-generates the PDF when the package count changes
  useEffect(() => {
    updateInstance();
  }, [packageCount, client, updateInstance]);

  const handlePrint = () => {
    if (instance.url && !instance.loading) {
      const printWindow = window.open(instance.url);
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
