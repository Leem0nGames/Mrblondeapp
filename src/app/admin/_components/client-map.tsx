
"use client";

import { useState } from 'react';
import { APIProvider, Map, AdvancedMarker, Pin, InfoWindow } from '@vis.gl/react-google-maps';
import type { Client } from '@/types';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { AlertTriangle } from 'lucide-react';

type ClientMapProps = {
  clients: Client[];
  center: { lat: number; lng: number };
  zoom: number;
  style?: React.CSSProperties;
};

export function ClientMap({ clients, center, zoom, style = { height: "400px" } }: ClientMapProps) {
  const apiKey = process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY;
  const [selectedClient, setSelectedClient] = useState<Client | null>(null);

  if (!apiKey) {
    return (
        <Alert variant="destructive">
            <AlertTriangle className="h-4 w-4" />
            <AlertTitle>Error de Configuración</AlertTitle>
            <AlertDescription>
                La clave de API de Google Maps (`NEXT_PUBLIC_GOOGLE_MAPS_API_KEY`) no está configurada en tu archivo `.env.local`. El mapa no puede funcionar sin ella.
            </AlertDescription>
        </Alert>
    )
  }
  
  // Filter out clients without valid coordinates
  const clientsWithCoords = clients.filter(c => c.latitude != null && c.longitude != null);
  
  if (clientsWithCoords.length === 0 && clients.length > 0) {
      return (
          <div className="flex items-center justify-center h-full bg-muted rounded-lg">
            <p className="text-muted-foreground p-4 text-center">
                {clients.length === 1 ? "Este cliente no tiene una dirección válida o aún no se han podido obtener sus coordenadas." : "Ninguno de estos clientes tiene coordenadas para mostrar en el mapa."}
            </p>
          </div>
      )
  }

  return (
    <div style={style} className="w-full rounded-lg overflow-hidden border">
        <APIProvider apiKey={apiKey}
            onLoad={() => console.log('Google Maps API cargada exitosamente.')}
        >
            <Map 
                zoom={zoom} 
                center={center} 
                gestureHandling={'greedy'}
                disableDefaultUI={true}
                className="w-full h-full"
            >
                {clientsWithCoords.map((client) => (
                    <AdvancedMarker 
                        key={client.id} 
                        position={{ lat: client.latitude!, lng: client.longitude! }}
                        onClick={() => setSelectedClient(client)}
                    />
                ))}

                {selectedClient && (
                    <InfoWindow 
                        position={{ lat: selectedClient.latitude!, lng: selectedClient.longitude! }}
                        onCloseClick={() => setSelectedClient(null)}
                    >
                       <p className="font-semibold">{selectedClient.contact_name}</p>
                    </InfoWindow>
                )}
            </Map>
        </APIProvider>
    </div>
  );
}
