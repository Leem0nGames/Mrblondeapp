
import { getClients } from "@/app/actions/admin.actions";
import { PageHeader } from "@/components/shared/page-header";
import { EmptyState } from "@/components/shared/empty-state";
import { Users, PlusCircle } from "lucide-react";
import { Button } from "@/components/ui/button";
import { ClientsTable } from "./_components/clients-table";
import { CreateClientButton } from "./_components/create-client-button";

export default async function ClientsPage() {
  const { data: clients, error } = await getClients();

  if (error) {
    // TODO: Add a better error component
    return <p className="text-destructive">{error.message}</p>;
  }

  const emptyState = (
    <EmptyState
      icon={Users}
      title="No hay clientes"
      description="Aún no tienes clientes. ¡Crea el primero para empezar!"
    >
        <CreateClientButton>
            <Button>
                <PlusCircle className="mr-2 h-4 w-4" />
                Crear Cliente
            </Button>
        </CreateClientButton>
    </EmptyState>
  );

  return (
    <div className="grid flex-1 items-start gap-4 md:gap-8">
       <PageHeader
        title="Clientes"
        description="Gestiona tus clientes, asígnales convenios y genera enlaces de alta."
      >
        <CreateClientButton>
            <Button size="sm" className="h-8 gap-1">
                <PlusCircle className="h-3.5 w-3.5" />
                <span className="sr-only sm:not-sr-only sm:whitespace-nowrap">
                    Crear Cliente
                </span>
            </Button>
        </CreateClientButton>
      </PageHeader>
      <ClientsTable clients={clients ?? []} emptyState={emptyState} />
    </div>
  );
}
