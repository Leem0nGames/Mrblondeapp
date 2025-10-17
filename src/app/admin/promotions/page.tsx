
import { Percent, PlusCircle } from "lucide-react";
import { Button } from "@/components/ui/button";
import { getPromotions } from "@/app/admin/actions/promotions.actions";
import PromotionsTable from "./_components/promotions-table";
import { PageHeader } from "@/components/shared/page-header";
import { EmptyState } from "@/components/shared/empty-state";
import { EntityDialog } from "../_components/entity-dialog";
import { promotionFormConfig } from "./_components/form-config";


export default async function PromotionsPage() {
  const { data: promotions, error } = await getPromotions();

  if (error) {
    return <p className="text-destructive">{error.message}</p>;
  }

  const emptyState = (
    <EmptyState
        icon={Percent}
        title="No hay promociones"
        description="Aún no has creado ninguna promoción. ¡Crea la primera para ofrecer beneficios a tus clientes!"
    >
        <EntityDialog formConfig={promotionFormConfig}>
            <Button>
                <PlusCircle className="mr-2 h-4 w-4" />
                Crear Promoción
            </Button>
        </EntityDialog>
    </EmptyState>
  );

  return (
   <div className="grid flex-1 items-start gap-4 md:gap-8">
      <PageHeader
        title="Promociones"
        description="Crea y gestiona las promociones y reglas de negocio de la tienda."
      >
        <EntityDialog formConfig={promotionFormConfig}>
            <Button size="sm" className="h-8 gap-1">
              <PlusCircle className="h-3.5 w-3.5" />
              <span className="sr-only sm:not-sr-only sm:whitespace-nowrap">
                Agregar Promoción
              </span>
            </Button>
          </EntityDialog>
      </PageHeader>
      
      <PromotionsTable promotions={promotions ?? []} emptyState={emptyState} />
    </div>
  );
}
