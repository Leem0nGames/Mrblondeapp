
import { Package, PlusCircle } from "lucide-react";
import { Button } from "@/components/ui/button";
import { getProducts } from "@/app/actions/admin.actions";
import ProductsTable from "./_components/products-table";
import { ProductDialog } from "./_components/product-dialog";
import { PageHeader } from "@/components/shared/page-header";
import { EmptyState } from "@/components/shared/empty-state";

export default async function ProductsPage() {
  const { data: products, error } = await getProducts();

  if (error) {
     return <p className="text-destructive">{error.message}</p>;
  }

  const emptyState = (
     <EmptyState
        icon={Package}
        title="No hay productos"
        description="Aún no has creado ningún producto. ¡Empieza por añadir el primero!"
    >
        <ProductDialog>
            <Button>
                <PlusCircle className="mr-2 h-4 w-4" />
                Crear Producto
            </Button>
        </ProductDialog>
    </EmptyState>
  );

  return (
   <div className="grid flex-1 items-start gap-4 md:gap-8">
      <PageHeader
        title="Productos"
        description="Gestiona tu catálogo de productos y su inventario."
      >
        <ProductDialog>
            <Button size="sm" className="h-8 gap-1">
              <PlusCircle className="h-3.5 w-3.5" />
              <span className="sr-only sm:not-sr-only sm:whitespace-nowrap">
                Agregar Producto
              </span>
            </Button>
          </ProductDialog>
      </PageHeader>
      
      <ProductsTable products={products ?? []} emptyState={emptyState} />
    </div>
  );
}
