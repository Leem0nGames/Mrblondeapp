
"use client";

import { useState, useEffect } from "react";
import { PDFDownloadLink } from "@react-pdf/renderer";
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import type { Client } from "@/types";
import { FileDown, Loader2 } from "lucide-react";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { ShippingLabelPDF } from "./shipping-label-pdf";

export function ShippingLabel({ client }: { client: Client }) {
  const [packageInfo, setPackageInfo] = useState("1 de 1");
  const [isClient, setIsClient] = useState(false);

  useEffect(() => {
    // PDFDownloadLink solo debe renderizarse en el cliente,
    // así que usamos este estado para evitar errores de hidratación.
    setIsClient(true);
  }, []);

  const getBultoCount = () => {
    const parts = packageInfo.split(' de ');
    return parseInt(parts[1], 10) || 1;
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle>Rótulo de Envío</CardTitle>
        <CardDescription>
          Genera un PDF con los rótulos para el paquete del cliente.
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="space-y-2">
          <Label htmlFor="package-info">Información de Bultos</Label>
          <Input 
            id="package-info"
            value={packageInfo}
            onChange={(e) => setPackageInfo(e.target.value)}
            placeholder="Ej: 1 de 3"
          />
           <p className="text-xs text-muted-foreground">Define cuántos rótulos generar. Ej: "3", "2 de 5".</p>
        </div>
      </CardContent>
      <CardFooter>
        {isClient ? (
          <PDFDownloadLink
            document={<ShippingLabelPDF client={client} totalBultos={getBultoCount()} />}
            fileName={`rotulos-${client.contact_name?.replace(/\s/g, '_') || client.id}.pdf`}
            className="w-full"
          >
            {({ loading }) => (
              <Button disabled={loading} className="w-full">
                {loading ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    Generando PDF...
                  </>
                ) : (
                  <>
                    <FileDown className="mr-2 h-4 w-4" />
                    Descargar PDF de Rótulos
                  </>
                )}
              </Button>
            )}
          </PDFDownloadLink>
        ) : (
          <Button disabled className="w-full">
            <Loader2 className="mr-2 h-4 w-4 animate-spin" />
            Cargando...
          </Button>
        )}
      </CardFooter>
    </Card>
  );
}
