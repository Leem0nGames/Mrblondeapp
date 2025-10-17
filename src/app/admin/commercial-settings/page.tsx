
import {
  Tabs,
  TabsContent,
  TabsList,
  TabsTrigger,
} from "@/components/ui/tabs";
import { PageHeader } from "@/components/shared/page-header";
import PriceListsTab from './_components/price-lists-tab';
import PromotionsTab from './_components/promotions-tab';
import SalesConditionsTab from './_components/sales-conditions-tab';
import Link from "next/link";

export default async function CommercialSettingsPage({
  searchParams,
}: {
  searchParams?: { tab?: string };
}) {
  const currentTab = searchParams?.tab || "pricelists";

  return (
    <div className="grid flex-1 items-start gap-4 md:gap-8">
      <PageHeader
        title="Gestión Comercial"
        description="Gestiona las listas de precios, promociones y condiciones de venta."
      />
      <Tabs value={currentTab} className="w-full">
        <TabsList className="grid w-full grid-cols-3">
           <TabsTrigger value="pricelists" asChild>
            <Link href="/admin/commercial-settings?tab=pricelists">Listas de Precios</Link>
          </TabsTrigger>
          <TabsTrigger value="promotions" asChild>
            <Link href="/admin/commercial-settings?tab=promotions">Promociones</Link>
          </TabsTrigger>
          <TabsTrigger value="sales-conditions" asChild>
             <Link href="/admin/commercial-settings?tab=sales-conditions">Condiciones de Venta</Link>
          </TabsTrigger>
        </TabsList>

        <TabsContent value="pricelists">
          <PriceListsTab />
        </TabsContent>
        <TabsContent value="promotions">
          <PromotionsTab />
        </TabsContent>
        <TabsContent value="sales-conditions">
          <SalesConditionsTab />
        </TabsContent>
      </Tabs>
    </div>
  );
}
