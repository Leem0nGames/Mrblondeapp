
import { Percent, PlusCircle } from "lucide-react";
import { Button } from "@/components/ui/button";
import { getPromotions } from "@/app/actions/admin.actions";
import { PromotionDialog } from "./_components/promotion-dialog";
import PromotionsTable from "./_components/promotions-table";
import { PageHeader } from "@/components/shared/page-header";
import { EmptyState } from "@/components/shared/empty-state";

export default async function PromotionsPage() {
  const { data: promotions, error } = await getPromotions();

  if (error) {
    return <p className="text-destructive">{error.message}</p>;
  }

  return (
   <div className="grid flex-1 items-start gap-4 md:gap-8">
      <PageHeader
        title="Promociones"
        description="Crea y gestiona las promociones y reglas de negocio de la tienda."
      >
        <PromotionDialog>
            <Button size="sm" className="h-8 gap-1">
              <PlusCircle className="h-3.5 w-3.5" />
              <span className="sr-only sm:not-sr-only sm:whitespace-nowrap">
                Agregar Promoción
              </span>
            </Button>
          </PromotionDialog>
      </PageHeader>
      
      {promotions && promotions.length > 0 ? (
        <PromotionsTable promotions={promotions ?? []} />
      ) : (
        <EmptyState
            icon={Percent}
            title="No hay promociones"
            description="Aún no has creado ninguna promoción. ¡Crea la primera para ofrecer beneficios a tus clientes!"
        >
            <PromotionDialog>
                <Button>
                    <PlusCircle className="mr-2 h-4 w-4" />
                    Crear Promoción
                </Button>
            </PromotionDialog>
        </EmptyState>
      )}
    </div>
  );
}
