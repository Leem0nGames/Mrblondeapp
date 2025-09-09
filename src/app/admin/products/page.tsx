import { PlusCircle } from "lucide-react";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Button } from "@/components/ui/button";
import { getProducts } from "@/app/actions/admin.actions";
import ProductsTable from "./_components/products-table";
import { ProductDialog } from "./_components/product-dialog";

export default async function ProductsPage() {
  const { data: products, error } = await getProducts();

  if (error) {
    return <p className="text-destructive">{error.message}</p>;
  }

  return (
    <Tabs defaultValue="all">
      <div className="flex items-center">
        <TabsList>
          <TabsTrigger value="all">All</TabsTrigger>
          <TabsTrigger value="active">Active</TabsTrigger>
          <TabsTrigger value="draft">Draft</TabsTrigger>
          <TabsTrigger value="archived" className="hidden sm:flex">
            Archived
          </TabsTrigger>
        </TabsList>
        <div className="ml-auto flex items-center gap-2">
          <ProductDialog>
            <Button size="sm" className="h-8 gap-1">
              <PlusCircle className="h-3.5 w-3.5" />
              <span className="sr-only sm:not-sr-only sm:whitespace-nowrap">
                Add Product
              </span>
            </Button>
          </ProductDialog>
        </div>
      </div>
      <TabsContent value="all">
        <ProductsTable products={products ?? []} />
      </TabsContent>
    </Tabs>
  );
}
