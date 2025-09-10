import Link from "next/link";
import { ArrowLeft, Edit, FileWarning, Package, Percent, PlusCircle } from "lucide-react";
import { getAgreementById } from "@/app/actions/admin.actions";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  Tabs,
  TabsContent,
  TabsList,
  TabsTrigger,
} from "@/components/ui/tabs";
import { AgreementDialog } from "../_components/agreement-dialog";
import AgreementProductsTable from "./_components/agreement-products-table";
import AgreementPromotionsList from "./_components/agreement-promotions-list";
import { AssignProductDialog } from "./_components/assign-product-dialog";
import { AssignPromotionDialog } from "./_components/assign-promotion-dialog";

export default async function AgreementDetailPage({
  params,
}: {
  params: { id: string };
}) {
  const { data: agreement, error } = await getAgreementById(params.id);

  if (error || !agreement) {
    return (
      <div className="flex flex-1 items-center justify-center rounded-lg border border-dashed shadow-sm">
        <div className="flex flex-col items-center gap-1 text-center">
          <FileWarning className="w-12 h-12 text-muted-foreground" />
          <h3 className="text-2xl font-bold tracking-tight">
            Convenio no encontrado
          </h3>
          <p className="text-sm text-muted-foreground">
            No se pudo encontrar el convenio solicitado o ocurrió un error.
          </p>
          <Button asChild className="mt-4">
            <Link href="/admin/agreements">Volver a Convenios</Link>
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className="grid flex-1 items-start gap-4 md:gap-8">
      <div className="flex items-center gap-4">
        <Button variant="outline" size="icon" className="h-7 w-7" asChild>
          <Link href="/admin/agreements">
            <ArrowLeft className="h-4 w-4" />
            <span className="sr-only">Volver</span>
          </Link>
        </Button>
        <div className="flex-1">
            <h1 className="text-2xl font-bold tracking-tight">{agreement.agreement_name}</h1>
            <p className="text-muted-foreground capitalize">{agreement.client_type}</p>
        </div>
        <div className="ml-auto flex items-center gap-2">
            <AgreementDialog agreement={agreement}>
                <Button size="sm" variant="outline" className="h-8 gap-1">
                    <Edit className="h-3.5 w-3.5" />
                    <span>Editar Detalles</span>
                </Button>
            </AgreementDialog>
        </div>
      </div>

      <Tabs defaultValue="products">
        <TabsList className="grid w-full grid-cols-2">
          <TabsTrigger value="products">
            <Package className="mr-2 h-4 w-4" />
            Productos Asignados ({agreement.agreement_products.length})
          </TabsTrigger>
          <TabsTrigger value="promotions">
             <Percent className="mr-2 h-4 w-4" />
            Promociones Asignadas ({agreement.agreement_promotions.length})
          </TabsTrigger>
        </TabsList>
        <TabsContent value="products">
          <Card>
            <CardHeader className="flex flex-row items-center">
              <div className="flex-grow">
                <CardTitle>Productos del Convenio</CardTitle>
                <CardDescription>
                  Gestiona los productos y sus precios específicos para este convenio.
                </CardDescription>
              </div>
               <AssignProductDialog agreementId={agreement.id}>
                  <Button size="sm" className="h-8 gap-1">
                    <PlusCircle className="h-3.5 w-3.5" />
                    <span>Asignar Producto</span>
                  </Button>
                </AssignProductDialog>
            </CardHeader>
            <CardContent>
              <AgreementProductsTable products={agreement.agreement_products} agreementId={agreement.id} />
            </CardContent>
          </Card>
        </TabsContent>
        <TabsContent value="promotions">
            <Card>
                <CardHeader className="flex flex-row items-center">
                    <div className="flex-grow">
                        <CardTitle>Promociones del Convenio</CardTitle>
                        <CardDescription>
                            Gestiona las promociones aplicables para este convenio.
                        </CardDescription>
                    </div>
                     <AssignPromotionDialog agreementId={agreement.id}>
                        <Button size="sm" className="h-8 gap-1">
                            <PlusCircle className="h-3.5 w-3.5" />
                            <span>Asignar Promoción</span>
                        </Button>
                     </AssignPromotionDialog>
                </CardHeader>
                <CardContent>
                    <AgreementPromotionsList promotions={agreement.agreement_promotions} agreementId={agreement.id} />
                </CardContent>
            </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
}
