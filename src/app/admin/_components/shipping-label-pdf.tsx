
"use client";

import React from 'react';
import { Page, Text, View, Document, StyleSheet, Image, Font } from '@react-pdf/renderer';
import type { Order, Client } from '@/types';

// Estilos para el PDF
const styles = StyleSheet.create({
  page: {
    padding: 30,
    backgroundColor: '#ffffff',
    fontFamily: 'Helvetica',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 20,
    borderBottom: 2,
    borderBottomColor: '#333',
    paddingBottom: 10,
  },
  logoContainer: {
    width: 120,
    height: 60,
  },
  orderInfo: {
    textAlign: 'right',
  },
  orderTitle: {
    fontSize: 18,
    fontWeight: 'bold',
  },
  orderDate: {
    fontSize: 10,
    color: '#666',
  },
  section: {
    marginBottom: 15,
  },
  sectionTitle: {
    fontSize: 10,
    color: '#666',
    textTransform: 'uppercase',
    marginBottom: 5,
    fontWeight: 'bold',
  },
  clientName: {
    fontSize: 22,
    fontWeight: 'bold',
    marginBottom: 5,
  },
  address: {
    fontSize: 14,
    marginBottom: 3,
  },
  location: {
    fontSize: 12,
    color: '#333',
    marginBottom: 10,
  },
  contactInfo: {
    fontSize: 10,
    color: '#444',
  },
  deliverySection: {
    marginTop: 10,
    padding: 10,
    backgroundColor: '#f9f9f9',
    borderRadius: 5,
    borderLeft: 4,
    borderLeftColor: '#d4af37', // Dorado Mr. Blonde
  },
  deliveryText: {
    fontSize: 12,
    fontWeight: 'bold',
  },
  qrSection: {
    marginTop: 20,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  qrPlaceholder: {
    width: 80,
    height: 80,
    backgroundColor: '#eee',
    justifyContent: 'center',
    alignItems: 'center',
  },
  notesSection: {
    marginTop: 30,
    border: 1,
    borderColor: '#ccc',
    borderRadius: 5,
    height: 100,
    padding: 10,
  },
  notesTitle: {
    fontSize: 9,
    color: '#999',
    position: 'absolute',
    top: 5,
    left: 10,
  }
});

type ShippingLabelProps = {
  order: Order;
  client: Client;
  logoUrl?: string | null;
};

export const ShippingLabelPDF = ({ order, client, logoUrl }: ShippingLabelProps) => {
  const date = new Date(order.created_at).toLocaleDateString('es-AR');
  
  // Generar URL de QR simple usando un servicio gratuito (para evitar dependencias pesadas en el bundle)
  const qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${order.id}`;

  return (
    <Document>
      <Page size="A5" style={styles.page}>
        {/* Header con Logo y Número de Pedido */}
        <View style={styles.header}>
          <View style={styles.logoContainer}>
            {logoUrl ? (
              <Image src={logoUrl} style={{ objectFit: 'contain' }} />
            ) : (
              <Text style={{ fontSize: 20, fontWeight: 'bold', color: '#d4af37' }}>MR. BLONDE</Text>
            )}
          </View>
          <View style={styles.orderInfo}>
            <Text style={styles.orderTitle}>PEDIDO #{order.id.slice(-6).toUpperCase()}</Text>
            <Text style={styles.orderDate}>Fecha: {date}</Text>
          </View>
        </View>

        {/* Datos del Cliente */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Destinatario</Text>
          <Text style={styles.clientName}>{client.contact_name}</Text>
          <Text style={styles.address}>{client.address || 'Sin dirección registrada'}</Text>
          <Text style={styles.contactInfo}>Email: {client.email}</Text>
          <Text style={styles.contactInfo}>CUIT: {client.cuit || 'N/A'}</Text>
        </View>

        {/* Ventana de Entrega */}
        <View style={styles.deliverySection}>
          <Text style={styles.sectionTitle}>Prioridad de Entrega</Text>
          <Text style={styles.deliveryText}>
            {client.delivery_window || 'Horario comercial habitual'}
          </Text>
        </View>

        {/* Notas y QR */}
        <View style={styles.qrSection}>
          <View style={{ flex: 1 }}>
             <View style={styles.notesSection}>
                <Text style={styles.notesTitle}>OBSERVACIONES DEL REPARTIDOR (Escrito a mano):</Text>
             </View>
          </View>
          <View style={{ marginLeft: 20 }}>
            <Image src={qrUrl} style={{ width: 80, height: 80 }} />
            <Text style={{ fontSize: 7, textAlign: 'center', marginTop: 4, color: '#999' }}>ID: {order.id.slice(0, 8)}</Text>
          </View>
        </View>

        <Text style={{ fontSize: 8, color: '#ccc', textAlign: 'center', marginTop: 20 }}>
          Generado automáticamente por Blonde Orders Order Management System
        </Text>
      </Page>
    </Document>
  );
};
