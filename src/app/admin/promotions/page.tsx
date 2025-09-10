import { PlusCircle } from "lucide-react";
import { Button } from "@/components/ui/button";
import { getPromotions } from "@/app/actions/admin.actions";
import { PromotionDialog } from "./_components/promotion-dialog";
import PromotionsTable from "./_components/promotions-table";

export default async function PromotionsPage() {
  const { data: promotions, error } = await getPromotions();

  if (error) {
    return <p className="text-destructive">{error.message}</p>;
  }

  return (
   <div className="grid flex-1 items-start gap-4 md:gap-8">
      <div className="flex items-center">
        <h1 className="text-2xl font-bold">Promociones</h1>
        <div className="ml-auto flex items-center gap-2">
          <PromotionDialog>
            <Button size="sm" className="h-8 gap-1">
              <PlusCircle className="h-3.5 w-3.5" />
              <span className="sr-only sm:not-sr-only sm:whitespace-nowrap">
                Agregar Promoción
              </span>
            </Button>
          </PromotionDialog>
        </div>
      </div>
      <PromotionsTable promotions={promotions ?? []} />
    </div>
  );
}
