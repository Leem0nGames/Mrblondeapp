import { PlusCircle } from "lucide-react";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Button } from "@/components/ui/button";
import { getProducts } from "@/app/actions/admin.actions";
import ProductsTable from "./_components/products-table";
import { ProductDialog } from "./_components/product-dialog";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";

export default async function ProductsPage() {
  const { data: products, error } = await getProducts();

  if (error) {
    return <p className="text-destructive">{error.message}</p>;
  }

  return (
   <div className="grid flex-1 items-start gap-4 md:gap-8">
      <div className="flex items-center">
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
      <Card>
        <CardHeader>
          <CardTitle>Products</CardTitle>
          <CardDescription>
            Manage your products and view their sales performance.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <ProductsTable products={products ?? []} />
        </CardContent>
      </Card>
    </div>
  );
}
