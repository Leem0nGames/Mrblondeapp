
import { ClipboardList, PlusCircle } from "lucide-react";
import { getPriceLists } from "@/app/admin/actions/pricelists.actions";
import { Button } from "@/components/ui/button";
import { PageHeader } from "@/components/shared/page-header";
import { EmptyState } from "@/components/shared/empty-state";
import { PriceListsTable } from "./_components/pricelists-table";
import { EntityDialog } from "../_components/entity-dialog";
import { priceListFormConfig } from "./_components/form-config";

export default async function PriceListsPage() {
  const { data: priceLists, error } = await getPriceLists();

  if (error) {
    return <p className="text-destructive">{error.message}</p>;
  }

  const emptyState = (
    <EmptyState
        icon={ClipboardList}
        title="No hay listas de precios"
        description="Crea tu primera lista para empezar a definir precios para tus productos."
    >
        <EntityDialog formConfig={priceListFormConfig}>
            <Button>
                <PlusCircle className="mr-2 h-4 w-4" />
                Crear Lista de Precios
            </Button>
        </EntityDialog>
    </EmptyState>
  );

  return (
    <div className="grid flex-1 items-start gap-4 md:gap-8">
      <PageHeader
        title="Listas de Precios"
        description="Crea y gestiona listas de precios reutilizables para tus convenios."
      >
        <EntityDialog formConfig={priceListFormConfig}>
            <Button size="sm" className="h-8 gap-1">
                <PlusCircle className="h-3.5 w-3.5" />
                <span className="sr-only sm:not-sr-only sm:whitespace-nowrap">
                    Crear Lista de Precios
                </span>
            </Button>
        </EntityDialog>
      </PageHeader>
      
      <PriceListsTable priceLists={priceLists ?? []} emptyState={emptyState} />
    </div>
  );
}
