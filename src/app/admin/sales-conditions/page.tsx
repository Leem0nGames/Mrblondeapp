
import { Landmark, PlusCircle } from "lucide-react";
import { Button } from "@/components/ui/button";
import { getSalesConditions } from "@/app/actions/admin.actions";
import SalesConditionsTable from "./_components/sales-conditions-table";
import { PageHeader } from "@/components/shared/page-header";
import { EmptyState } from "@/components/shared/empty-state";
import { EntityDialog } from "../_components/entity-dialog";
import { salesConditionFormConfig } from "./_components/form-config";


export default async function SalesConditionsPage() {
  const { data: salesConditions, error } = await getSalesConditions();

  if (error) {
    return <p className="text-destructive">{error.message}</p>;
  }

  const emptyState = (
    <EmptyState
        icon={Landmark}
        title="No hay condiciones de venta"
        description="Crea tu primera condición para definir plazos de pago, descuentos o formas de financiación."
    >
        <EntityDialog formConfig={salesConditionFormConfig}>
            <Button>
                <PlusCircle className="mr-2 h-4 w-4" />
                Crear Condición
            </Button>
        </EntityDialog>
    </EmptyState>
  );

  return (
   <div className="grid flex-1 items-start gap-4 md:gap-8">
      <PageHeader
        title="Condiciones de Venta"
        description="Gestiona las condiciones comerciales como plazos de pago, descuentos y financiación."
      >
        <EntityDialog formConfig={salesConditionFormConfig}>
            <Button size="sm" className="h-8 gap-1">
              <PlusCircle className="h-3.5 w-3.5" />
              <span className="sr-only sm:not-sr-only sm:whitespace-nowrap">
                Agregar Condición
              </span>
            </Button>
          </EntityDialog>
      </PageHeader>
      
      <SalesConditionsTable salesConditions={salesConditions ?? []} emptyState={emptyState} />
    </div>
  );
}
