
import { getDashboardStats, getPendingOrders } from "@/app/admin/actions/dashboard.actions";
import { getClients, getClientsWithPendingAgreements } from "@/app/admin/actions/clients.actions";
import { PageHeader } from "@/components/shared/page-header";
import { 
    Card,
    CardContent,
    CardDescription,
    CardHeader,
    CardTitle,
} from "@/components/ui/card";
import { DashboardStats } from "./_components/dashboard-stats";
import { RecentOrders } from "./_components/recent-orders";
import { PendingClients } from "./_components/pending-clients";
import { ClientMap } from "./_components/client-map";

export default async function AdminDashboardPage() {
    const [stats, pendingOrders, pendingClients, allClients] = await Promise.all([
      getDashboardStats(),
      getPendingOrders(),
      getClientsWithPendingAgreements(),
      getClients()
    ]);
    
    const clientsWithCoords = allClients.data?.filter(c => c.latitude && c.longitude) ?? [];

    return (
        <div className="grid flex-1 items-start gap-4 md:gap-8">
            <PageHeader
                title="Dashboard"
                description="Un resumen de la actividad de tu negocio."
            />
            <DashboardStats stats={stats} />
            <div className="grid gap-4 md:gap-8 lg:grid-cols-2 xl:grid-cols-3">
                <Card className="xl:col-span-2">
                    <CardHeader>
                        <CardTitle>Pedidos Recientes</CardTitle>
                        <CardDescription>
                            Pedidos pendientes de cargar en el sistema de gestión.
                        </CardDescription>
                    </CardHeader>
                    <CardContent>
                        <RecentOrders orders={pendingOrders} />
                    </CardContent>
                </Card>
                <div className="space-y-4">
                  <Card>
                      <CardHeader>
                          <CardTitle>Clientes Pendientes</CardTitle>
                          <CardDescription>
                              Clientes que completaron el alta y esperan un convenio.
                          </CardDescription>
                      </CardHeader>
                      <CardContent>
                        <PendingClients clients={pendingClients} />
                      </CardContent>
                  </Card>
                   <Card>
                      <CardHeader>
                          <CardTitle>Mapa de Clientes</CardTitle>
                          <CardDescription>
                              Ubicación de tus clientes activos.
                          </CardDescription>
                      </CardHeader>
                      <CardContent>
                        <ClientMap 
                           clients={clientsWithCoords}
                           center={{ lat: -38.4161, lng: -63.6167 }} // Center of Argentina
                           zoom={4}
                        />
                      </CardContent>
                  </Card>
                </div>
            </div>
        </div>
    );
}
