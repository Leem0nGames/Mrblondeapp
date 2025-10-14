
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
  const [packageInfo, setPackageInfo] = useState("1");
  const [isClient, setIsClient] = useState(false);

  // This effect is necessary to signal that we are on the client
  // and that @react-pdf/renderer can start its work.
  useEffect(() => {
    setIsClient(true);
  }, []);
  
  const getBultoCount = () => {
    const input = packageInfo.trim();
    if (!input) return 1;
    const match = input.match(/\d+/g);
    if (match) {
        return parseInt(match[match.length - 1], 10) || 1;
    }
    return 1;
  };

  if (!isClient) {
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
            <Label htmlFor="package-info">Número de Bultos</Label>
            <Input 
              id="package-info"
              value={packageInfo}
              onChange={(e) => setPackageInfo(e.target.value)}
              placeholder="Ej: 3"
              disabled
            />
             <p className="text-xs text-muted-foreground">Define cuántos rótulos generar. Ej: "3" generará 3 rótulos.</p>
          </div>
        </CardContent>
        <CardFooter>
           <Button disabled className="w-full">
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              Cargando Generador...
            </Button>
        </CardFooter>
      </Card>
    );
  }

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
          <Label htmlFor="package-info">Número de Bultos</Label>
          <Input 
            id="package-info"
            value={packageInfo}
            onChange={(e) => setPackageInfo(e.target.value)}
            placeholder="Ej: 3"
          />
           <p className="text-xs text-muted-foreground">Define cuántos rótulos generar. Ej: "3" generará 3 rótulos.</p>
        </div>
      </CardContent>
      <CardFooter>
        <PDFDownloadLink
          document={<ShippingLabelPDF client={client} totalBultos={getBultoCount()} />}
          fileName={`rotulos-${client.contact_name?.replace(/\s/g, '_') || client.id}.pdf`}
          className="w-full"
        >
          {({ loading }) => (
            <Button disabled={loading || !packageInfo} className="w-full">
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
      </CardFooter>
    </Card>
  );
}
