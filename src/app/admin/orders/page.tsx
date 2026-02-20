
import { getOrders } from "@/app/admin/actions/orders.actions";
import { PageHeader } from "@/components/shared/page-header";
import { Card, CardContent } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { formatDate } from "@/lib/utils";
import { ShippingLabelButton } from "../_components/shipping-label-button";
import { OrderStatusBadge } from "../_components/order-status-badge";

export default async function OrdersHistoryPage({
  searchParams,
}: {
  searchParams?: { status?: string; query?: string };
}) {
  const { data: orders } = await getOrders({ 
    status: searchParams?.status, 
    query: searchParams?.query 
  });

  return (
    <div className="grid gap-4 md:gap-8">
      <PageHeader 
        title="Historial de Pedidos" 
        description="Revisa y gestiona todos los pedidos realizados en el sistema." 
      />
      <Card>
        <CardContent className="p-0">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Fecha</TableHead>
                <TableHead>Cliente</TableHead>
                <TableHead>Monto</TableHead>
                <TableHead>Estado</TableHead>
                <TableHead className="text-right">Rótulos</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {orders?.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={5} className="text-center py-8 text-muted-foreground">
                    No se encontraron pedidos.
                  </TableCell>
                </TableRow>
              ) : (
                orders?.map((order) => (
                  <TableRow key={order.id}>
                    <TableCell>{formatDate(order.created_at)}</TableCell>
                    <TableCell className="font-medium">{order.client_name_cache}</TableCell>
                    <TableCell>${order.total_amount.toLocaleString()}</TableCell>
                    <TableCell><OrderStatusBadge status={order.status} /></TableCell>
                    <TableCell className="text-right">
                      <ShippingLabelButton orders={[{ id: order.id, bundles: 1 }]} />
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    </div>
  );
}
