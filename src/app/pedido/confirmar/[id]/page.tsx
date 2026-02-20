import { getPublicOrderDetails, publicConfirmOrder } from "@/app/admin/actions/orders.actions";
import { Logo } from "@/app/logo";
import { Card, CardContent, CardDescription, CardHeader, CardTitle, CardFooter } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { CheckCircle2, PackageCheck } from "lucide-react";
import { redirect } from "next/navigation";

export default async function OrderConfirmationPortal({ params, searchParams }: { params: { id: string }, searchParams: { success?: string } }) {
  const { data: order, error } = await getPublicOrderDetails(params.id);

  if (error || !order) {
    return (
      <div className="min-h-screen flex flex-col items-center justify-center p-4 bg-muted/20">
        <Card className="w-full max-w-md text-center">
          <CardHeader>
            <CardTitle>Pedido no encontrado</CardTitle>
            <CardDescription>El enlace podría ser inválido o el pedido ya no existe.</CardDescription>
          </CardHeader>
        </Card>
      </div>
    );
  }

  const handleConfirm = async () => {
    'use server';
    await publicConfirmOrder(params.id);
    redirect(`/pedido/confirmar/${params.id}?success=true`);
  };

  if (searchParams.success === 'true' || order.status === 'entregado') {
    return (
      <div className="min-h-screen flex flex-col items-center justify-center p-4 bg-muted/20">
        <Logo showText={true} className="mb-8" />
        <Card className="w-full max-w-md text-center">
          <CardHeader>
            <div className="flex justify-center mb-4 text-primary">
              <CheckCircle2 className="h-16 w-16" />
            </div>
            <CardTitle className="text-2xl">¡Pedido Entregado!</CardTitle>
            <CardDescription>Muchas gracias por confirmar la recepción conforme.</CardDescription>
          </CardHeader>
          <CardContent>
            <p className="text-muted-foreground">Tu aviso de entrega ha sido enviado al equipo de Mr. Blonde. ¡Esperamos verte pronto!</p>
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex flex-col items-center justify-center p-4 bg-muted/20">
      <Logo showText={true} className="mb-8" />
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle>Conformidad de Entrega</CardTitle>
          <CardDescription>Hola {order.client_name_cache}, ¿recibiste tu pedido correctamente?</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="bg-muted/50 p-4 rounded-lg">
            <p className="font-semibold text-sm mb-2">Resumen del Pedido:</p>
            <ul className="text-sm space-y-1">
              {order.order_items?.map((item: any, i: number) => (
                <li key={i} className="flex justify-between">
                  <span>{item.products?.name}</span>
                  <span className="font-bold">x{item.quantity}</span>
                </li>
              ))}
            </ul>
          </div>
        </CardContent>
        <CardFooter>
          <form action={handleConfirm} className="w-full">
            <Button size="lg" className="w-full gap-2">
              <PackageCheck className="h-5 w-5" />
              Avisar Conforme
            </Button>
          </form>
        </CardFooter>
      </Card>
    </div>
  );
}
