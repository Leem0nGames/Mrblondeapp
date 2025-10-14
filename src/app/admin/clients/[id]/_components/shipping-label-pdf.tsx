
"use client";

import React from 'react';
import { Page, Text, View, Document, StyleSheet, Font } from '@react-pdf/renderer';
import type { Client } from '@/types';

// --- Estilos del PDF ---
// Nota: @react-pdf/renderer no soporta todas las propiedades de CSS.
// Hay que ser muy específico y usar propiedades que sí soporta.
const styles = StyleSheet.create({
  page: {
    padding: 30,
    fontFamily: 'Helvetica',
  },
  label: {
    border: '1pt solid #e5e7eb',
    borderRadius: 8,
    padding: 16,
    marginBottom: 20,
    height: '251pt', // Aproximadamente un cuarto de A4
    flexDirection: 'column',
    justifyContent: 'space-between',
  },
  mainContent: {
    flexDirection: 'row',
  },
  leftColumn: {
    width: '25%',
    flexDirection: 'column',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingRight: 10,
  },
  rightColumn: {
    width: '75%',
    flexDirection: 'column',
  },
  logoText: {
    fontFamily: 'Helvetica-Bold',
    fontSize: '10pt',
    textAlign: 'center',
    marginBottom: 10,
  },
  qrCode: {
    width: 80,
    height: 80,
    marginBottom: 10,
  },
  clientInfoContainer: {
    marginBottom: 12,
  },
  clientName: {
    fontSize: '14pt',
    fontFamily: 'Helvetica-Bold',
    color: '#2563eb', // azul
  },
  clientCuit: {
    fontSize: '9pt',
    color: '#374151',
    marginTop: 2,
  },
  labelSection: {
    fontSize: '10pt',
    marginTop: 12,
  },
  labelText: {
    fontFamily: 'Helvetica-Bold',
  },
  deliveryWindow: {
    backgroundColor: '#1f2937',
    color: 'white',
    fontSize: '9pt',
    padding: 6,
    borderRadius: 4,
    marginTop: 12,
  },
  notes: {
    fontSize: '10pt',
    marginTop: 12,
  },
  footer: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    marginTop: 10,
  },
  bultoText: {
    backgroundColor: '#374151',
    color: 'white',
    fontSize: '9pt',
    fontFamily: 'Helvetica-Bold',
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 4,
  },
});

interface ShippingLabelPDFProps {
  client: Client;
  totalBultos: number;
}

const LabelComponent = ({ client, currentBulto, totalBultos }: { client: Client, currentBulto: number, totalBultos: number }) => {
  const qrCodeUrl = `https://api.qrserver.com/v1/create-qr-code/?size=100x100&data=${encodeURIComponent(client.id)}&qzone=1`;

  return (
    <View style={styles.label} wrap={false}>
      <View style={styles.mainContent}>
        <View style={styles.leftColumn}>
          <Text style={styles.logoText}>MR. BLONDE</Text>
          {/* @react-pdf/renderer no puede cargar imágenes externas sin configuración especial, usaremos un placeholder */}
        </View>
        <View style={styles.rightColumn}>
          <View style={styles.clientInfoContainer}>
            <Text style={styles.clientName}>
              {(client.contact_name || "NOMBRE NO ESPECIFICADO").toUpperCase()}
            </Text>
            <Text style={styles.clientCuit}>CUIT/CUIL: {client.cuit || "N/A"}</Text>
          </View>
          <View style={styles.labelSection}>
            <Text><Text style={styles.labelText}>DIRECCIÓN:</Text> {client.address || "No especificada"}</Text>
          </View>
           <View style={styles.deliveryWindow}>
            <Text>
              <Text style={styles.labelText}>DÍAS Y HORARIOS:</Text> {client.delivery_window || "No especificado"}
            </Text>
          </View>
          <View style={styles.notes}>
            <Text><Text style={styles.labelText}>NOTAS:</Text> _____________________________________</Text>
          </View>
        </View>
      </View>
      <View style={styles.footer}>
        <Text style={styles.bultoText}>Bulto {currentBulto} de {totalBultos}</Text>
      </View>
    </View>
  );
};


export const ShippingLabelPDF = ({ client, totalBultos }: ShippingLabelPDFProps) => {
    const labels = Array.from({ length: totalBultos }, (_, i) => i + 1);

    return (
        <Document>
            <Page size="A4" style={styles.page}>
            {labels.map((bultoNum) => (
                <LabelComponent 
                    key={bultoNum}
                    client={client} 
                    currentBulto={bultoNum}
                    totalBultos={totalBultos}
                />
            ))}
            </Page>
        </Document>
    );
};
