
"use client";

import React, { useState, useEffect } from 'react';
import { PDFDownloadLink } from '@react-pdf/renderer';
import { Printer, Loader2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { ShippingLabelPDF } from './shipping-label-pdf';
import type { Order, Client } from '@/types';
import { getClientById } from '../actions/clients.actions';
import { getSettings } from '../actions/settings.actions';

type ShippingLabelButtonProps = {
  order: Order;
  variant?: "outline" | "ghost" | "default";
  size?: "sm" | "icon" | "default";
};

export function ShippingLabelButton({ order, variant = "outline", size = "sm" }: ShippingLabelButtonProps) {
  const [client, setClient] = useState<Client | null>(null);
  const [logoUrl, setLogoUrl] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  const loadData = async () => {
    setIsLoading(true);
    try {
      const [{ data: clientData }, settings] = await Promise.all([
        getClientById(order.client_id),
        getSettings()
      ]);
      setClient(clientData);
      setLogoUrl(settings.logo_url);
    } catch (error) {
      console.error("Error loading label data:", error);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div onMouseEnter={() => { if (!client) loadData(); }}>
      {!client || isLoading ? (
        <Button variant={variant} size={size} disabled={isLoading} onClick={loadData}>
          {isLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : <Printer className="h-4 w-4" />}
          {size !== "icon" && <span className="ml-2">Rótulo</span>}
        </Button>
      ) : (
        <PDFDownloadLink
          document={<ShippingLabelPDF order={order} client={client} logoUrl={logoUrl} />}
          fileName={`rotulo-${client.contact_name?.replace(/\s+/g, '-').toLowerCase()}-${order.id.slice(-4)}.pdf`}
        >
          {({ loading }) => (
            <Button variant={variant} size={size} disabled={loading}>
              <Printer className="h-4 w-4" />
              {size !== "icon" && <span className="ml-2">{loading ? "Generando..." : "Imprimir Rótulo"}</span>}
            </Button>
          )}
        </PDFDownloadLink>
      )}
    </div>
  );
}
