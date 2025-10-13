
"use client";

import { useState } from "react";
import Image from "next/image";
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import type { Client } from "@/types";
import { Printer } from "lucide-react";
import { Separator } from "@/components/ui/separator";
import { Logo } from "@/components/logo";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

export function ShippingLabel({ client }: { client: Client }) {
  const [packageInfo, setPackageInfo] = useState("1 de 1");
    
  const handlePrint = () => {
    window.print();
  };

  const qrCodeUrl = `https://api.qrserver.com/v1/create-qr-code/?size=100x100&data=${encodeURIComponent(client.id)}&qzone=1`;

  return (
    <Card id="shipping-label-card">
      <CardHeader className="no-print">
        <CardTitle>Rótulo de Envío</CardTitle>
        <CardDescription>
          Genera una etiqueta para el paquete del cliente. Puedes ajustar el número de bulto antes de imprimir.
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        {/* --- Seccion visible en la app --- */}
        <div className="no-print space-y-2">
            <Label htmlFor="package-info">Info de Bulto</Label>
            <Input 
                id="package-info"
                value={packageInfo}
                onChange={(e) => setPackageInfo(e.target.value)}
                placeholder="Ej: 1 de 3"
            />
        </div>
        
        {/* --- Contenedor del Rotulo para impresion --- */}
        <div className="print-content-area space-y-4">
            {/* Usamos un bucle para que si el usuario pone "1 de 3", se generen 3 etiquetas */}
            {Array.from({ length: parseInt(packageInfo.split(' de ')[1] || '1', 10) }, (_, i) => {
                const currentBulto = i + 1;
                const totalBultos = parseInt(packageInfo.split(' de ')[1] || '1', 10);
                const bultoText = `Bulto ${currentBulto} de ${totalBultos}`;

                return (
                    <div key={i} className="shipping-label-wrapper border rounded-lg p-4 space-y-4 break-inside-avoid">
                        <div className="flex gap-4">
                            {/* Columna Izquierda: Logo y QR */}
                            <div className="w-1/4 flex flex-col items-center justify-between gap-2">
                                <Logo showText isMono className="flex-col !items-start text-xs gap-0" />
                                <Image 
                                    src={qrCodeUrl}
                                    alt="Código QR del cliente"
                                    width={80}
                                    height={80}
                                    className="object-contain"
                                    unoptimized // Necesario para servicios de QR externos
                                />
                            </div>

                            {/* Columna Derecha: Información */}
                            <div className="w-3/4 space-y-2 text-sm">
                                <div>
                                    <p className="font-bold text-base text-blue-600">{client.contact_name?.toUpperCase() || "NOMBRE NO ESPECIFICADO"}</p>
                                    <p className="text-xs text-gray-700">CUIT/CUIL: {client.cuit || "N/A"}</p>
                                </div>
                                <div>
                                    <p><span className="font-semibold">DIRECCIÓN:</span> {client.address || "No especificada"}</p>
                                </div>
                                <div className="bg-gray-800 text-white text-xs p-2 rounded-md">
                                    <p><span className="font-semibold">DÍAS Y HORARIOS:</span> {client.delivery_window || "No especificado"}</p>
                                </div>
                                <div>
                                    <p><span className="font-semibold">NOTAS:</span> _________________________________</p>
                                </div>
                            </div>
                        </div>
                        <div className="flex justify-end">
                            <p className="bg-gray-700 text-white text-xs font-semibold px-3 py-1 rounded-md">{bultoText}</p>
                        </div>
                    </div>
                )
            })}
        </div>

      </CardContent>
      <CardFooter className="no-print">
        <Button onClick={handlePrint} className="w-full">
          <Printer className="mr-2 h-4 w-4" />
          Imprimir Rótulo(s)
        </Button>
      </CardFooter>
    </Card>
  );
}
