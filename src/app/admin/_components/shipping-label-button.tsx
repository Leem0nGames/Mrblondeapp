"use client";

import { useState, useEffect } from "react";
import { PDFDownloadLink, Document, Page, Text, View, StyleSheet, Image as PDFImage } from "@react-pdf/renderer";
import { Button } from "@/components/ui/button";
import { Printer, Loader2 } from "lucide-react";
import { getOrderWithDetails } from "@/app/admin/actions/orders.actions";
import { useToast } from "@/hooks/use-toast";

const styles = StyleSheet.create({
  page: { padding: 30, backgroundColor: "#FFFFFF" },
  labelContainer: {
    width: "100%",
    height: "33.33%",
    padding: 20,
    borderBottom: "1pt dashed #CCCCCC",
    display: "flex",
    flexDirection: "row",
    justifyContent: "space-between",
  },
  leftColumn: { width: "65%" },
  rightColumn: { width: "30%", alignItems: "center", justifyContent: "center" },
  header: { fontSize: 24, fontWeight: "bold", marginBottom: 10, color: "#000000" },
  clientName: { fontSize: 18, fontWeight: "bold", marginBottom: 5 },
  address: { fontSize: 14, marginBottom: 15, color: "#333333" },
  footer: { marginTop: "auto", fontSize: 10, color: "#666666" },
  bundleInfo: { fontSize: 16, fontWeight: "bold", marginTop: 10, color: "#E6D5A7", backgroundColor: "#000000", padding: 5, textAlign: "center" },
  qrText: { fontSize: 8, textAlign: "center" },
});

const LabelsPDF = ({ ordersData, origin }: { ordersData: any[], origin: string }) => (
  <Document>
    <Page size="A4" style={styles.page}>
      {ordersData.map((order, idx) => (
        <View key={`${order.id}-${idx}`} style={styles.labelContainer}>
          <View style={styles.leftColumn}>
            <Text style={styles.header}>MR. BLONDE</Text>
            <Text style={styles.clientName}>{order.client_name_cache || "Cliente"}</Text>
            <Text style={styles.address}>{order.clients?.address || "Dirección no registrada"}</Text>
            <Text style={styles.footer}>Pedido #{order.id?.slice(-6).toUpperCase()} | {new Date().toLocaleDateString()}</Text>
          </View>
          <View style={styles.rightColumn}>
            <PDFImage 
                src={`https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${encodeURIComponent(`${origin}/pedido/confirmar/${order.id}`)}`}
                style={{ width: 80, height: 80, marginBottom: 5 }}
            />
            <Text style={styles.qrText}>SCAN PARA CONFORMAR</Text>
            <Text style={styles.bundleInfo}>BULTO {order.bundleIdx} DE {order.totalBundles}</Text>
          </View>
        </View>
      ))}
    </Page>
  </Document>
);

export function ShippingLabelButton({ orders }: { orders: { id: string, bundles: number }[] }) {
  const [loading, setLoading] = useState(false);
  const [data, setData] = useState<any[] | null>(null);
  const [origin, setOrigin] = useState("");
  const { toast } = useToast();

  useEffect(() => {
    setOrigin(window.location.origin);
  }, []);

  const loadData = async () => {
    setLoading(true);
    try {
      const ordersWithDetails = await Promise.all(
        orders.map(async (o) => {
          const res = await getOrderWithDetails(o.id);
          if (res.error) throw res.error;
          if (!res.data) throw new Error("No data returned for order " + o.id);
          
          const labels = [];
          for (let i = 1; i <= o.bundles; i++) {
            labels.push({
              ...res.data,
              bundleIdx: i,
              totalBundles: o.bundles
            });
          }
          return labels;
        })
      );
      setData(ordersWithDetails.flat());
    } catch (err: any) {
      console.error("Error loading label data:", err);
      toast({ title: "Error", description: err.message || "No se pudieron cargar los datos de envío.", variant: "destructive" });
    } finally {
      setLoading(false);
    }
  };

  if (!data) {
    return (
      <Button variant="outline" size="sm" onClick={loadData} disabled={loading} className="gap-2">
        {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : <Printer className="h-4 w-4" />}
        Generar Rótulos
      </Button>
    );
  }

  return (
    <div className="flex items-center gap-2">
        <PDFDownloadLink
            document={<LabelsPDF ordersData={data} origin={origin} />}
            fileName={`rotulos-${new Date().getTime()}.pdf`}
            className="inline-flex"
        >
            {({ loading: pdfLoading }) => (
                <Button size="sm" variant="default" className="gap-2" disabled={pdfLoading}>
                    <Printer className="h-4 w-4" />
                    Descargar PDF ({data.length} bultos)
                </Button>
            )}
        </PDFDownloadLink>
        <Button variant="ghost" size="sm" onClick={() => setData(null)}>Limpiar</Button>
    </div>
  );
}
