
"use client";

import React from 'react';
import { Page, Text, View, Document, StyleSheet, Image, Font } from '@react-pdf/renderer';
import type { Client } from '@/types';

// --- Registrar Fuentes ---
// Nota: Las rutas deben ser absolutas o relativas al lugar desde donde se sirve.
// Como estamos en un entorno Next.js, las ponemos en /public.
// Es crucial que estos archivos de fuente existan en la carpeta /public.
// Por simplicidad, usaremos fuentes genéricas y especificaremos fallbacks.

Font.register({
  family: 'Belleza',
  src: 'https://fonts.gstatic.com/s/belleza/v15/0nkoC9_pYxnY_Uvyw3oz.ttf',
});

Font.register({
  family: 'Alegreya',
  src: 'https://fonts.gstatic.com/s/alegreya/v35/4UacrEBBsYupSs_UpDQssKTT.ttf'
});


// --- Estilos del PDF ---
const styles = StyleSheet.create({
  page: {
    padding: 30,
    fontFamily: 'Alegreya',
  },
  label: {
    border: 1,
    borderColor: '#e5e7eb',
    borderRadius: 8,
    padding: 16,
    marginBottom: 20,
    height: '251pt', // Aprox 1/3 de una página A4 menos márgenes
  },
  row: {
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
    gap: 6,
  },
  logoText: {
    fontFamily: 'Belleza',
    fontSize: 10,
    fontWeight: 'bold',
    textAlign: 'center',
  },
  qrCode: {
    width: 80,
    height: 80,
  },
  clientName: {
    fontSize: 14,
    fontWeight: 'bold',
    color: '#2563eb', // text-blue-600
    textTransform: 'uppercase',
  },
  clientCuit: {
    fontSize: 9,
    color: '#374151', // text-gray-700
  },
  labelSection: {
    fontSize: 10,
  },
  labelText: {
    fontWeight: 'bold',
  },
  deliveryWindow: {
    backgroundColor: '#1f2937', // bg-gray-800
    color: 'white',
    fontSize: 9,
    padding: 6,
    borderRadius: 4,
  },
  notes: {
    fontSize: 10,
  },
  footer: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    marginTop: 8,
  },
  bultoText: {
    backgroundColor: '#374151', // bg-gray-700
    color: 'white',
    fontSize: 9,
    fontWeight: 'bold',
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
    <View style={styles.label}>
      <View style={styles.row}>
        <View style={styles.leftColumn}>
          <Text style={styles.logoText}>MR. BLONDE</Text>
          <Image
            style={styles.qrCode}
            src={qrCodeUrl}
          />
        </View>
        <View style={styles.rightColumn}>
          <View>
            <Text style={styles.clientName}>{client.contact_name?.toUpperCase() || "NOMBRE NO ESPECIFICADO"}</Text>
            <Text style={styles.clientCuit}>CUIT/CUIL: {client.cuit || "N/A"}</Text>
          </View>
          <View style={styles.labelSection}>
            <Text><Text style={styles.labelText}>DIRECCIÓN:</Text> {client.address || "No especificada"}</Text>
          </View>
          <View style={styles.deliveryWindow}>
            <Text><Text style={styles-labelText}>DÍAS Y HORARIOS:</Text> {client.delivery_window || "No especificado"}</Text>
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
    // Crea un array con el número de etiquetas a generar
    const labels = Array.from({ length: totalBultos }, (_, i) => i + 1);

    // Agrupa las etiquetas en páginas de 3
    const pages = labels.reduce<number[][]>((acc, _, i) => {
        if (i % 3 === 0) {
            acc.push(labels.slice(i, i + 3));
        }
        return acc;
    }, []);

    return (
        <Document>
        {pages.map((pageLabels, pageIndex) => (
            <Page key={pageIndex} size="A4" style={styles.page}>
            {pageLabels.map((bultoNum) => (
                <LabelComponent 
                    key={bultoNum}
                    client={client} 
                    currentBulto={bultoNum}
                    totalBultos={totalBultos}
                />
            ))}
            </Page>
        ))}
        </Document>
    );
};
