
"use client";

import { useState } from 'react';
import { APIProvider, Map, AdvancedMarker, Pin, InfoWindow } from '@vis.gl/react-google-maps';
import type { Client } from '@/types';
import { Card, CardContent } from '@/components/ui/card';

type ClientMapProps = {
  clients: Client[];
  zoom?: number;
  center?: { lat: number; lng: number };
  mapId?: string;
  height?: string;
};

const defaultCenter = { lat: -38.4161, lng: -63.6167 }; // Center of Argentina

export function ClientMap({ clients, zoom = 4, center = defaultCenter, mapId = "argentina-map", height = "400px" }: ClientMapProps) {
  const apiKey = process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY;
  const [selectedClient, setSelectedClient] = useState<Client | null>(null);

  if (!apiKey) {
    return (
      <Card>
        <CardContent className="pt-6">
          <p className="text-destructive">La clave API de Google Maps no está configurada.</p>
          <p className="text-sm text-muted-foreground">Añade NEXT_PUBLIC_GOOGLE_MAPS_API_KEY a tu .env.local para mostrar el mapa.</p>
        </CardContent>
      </Card>
    );
  }
  
  const clientsWithCoords = clients.filter(c => c.latitude && c.longitude);

  return (
    <APIProvider apiKey={apiKey}>
      <div style={{ height, width: '100%' }}>
        <Map
          zoom={zoom}
          center={center}
          mapId={mapId}
          gestureHandling={'greedy'}
          disableDefaultUI={true}
        >
          {clientsWithCoords.map((client) => (
            <AdvancedMarker
              key={client.id}
              position={{ lat: client.latitude!, lng: client.longitude! }}
              onClick={() => setSelectedClient(client)}
            >
              <Pin />
            </AdvancedMarker>
          ))}

          {selectedClient && (
            <InfoWindow
              position={{ lat: selectedClient.latitude!, lng: selectedClient.longitude! }}
              onCloseClick={() => setSelectedClient(null)}
            >
              <div className="p-2">
                <h3 className="font-bold">{selectedClient.contact_name}</h3>
                <p className="text-sm">{selectedClient.address}</p>
              </div>
            </InfoWindow>
          )}
        </Map>
      </div>
    </APIProvider>
  );
}
