import { getOrderPageData } from "@/app/actions/user.actions";
import { ProductCard } from "./_components/product-card";
import { Logo } from "@/components/logo";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { AlertTriangle } from "lucide-react";
import { CartWidget } from "./_components/cart-widget";

export default async function OrderPage({
  params,
}: {
  params: { token: string };
}) {
  const { data, error } = await getOrderPageData(params.token);

  if (error || !data) {
    return (
      <div className="flex h-screen flex-col items-center justify-center bg-background p-8 text-center">
        <Logo className="mb-8" />
        <Card className="max-w-md">
          <CardHeader>
            <CardTitle className="flex items-center justify-center gap-2 text-destructive">
              <AlertTriangle />
              Error
            </Title>
          </CardHeader>
          <CardContent>
            <p className="text-lg text-muted-foreground">{error?.message || "Algo salió mal."}</p>
            <p className="mt-2 text-sm text-muted-foreground">
              Por favor, contacta al administrador o solicita un nuevo enlace.
            </p>
          </CardContent>
        </Card>
      </div>
    );
  }

  const { agreement, products } = data;

  return (
    <div className="min-h-screen bg-muted/20">
      <header className="sticky top-0 z-40 border-b bg-background/80 backdrop-blur-sm">
        <div className="container mx-auto flex h-16 items-center justify-between px-4">
          <Logo />
          <div className="text-right">
            <p className="font-semibold text-foreground">{agreement.client_name}</p>
            <p className="text-sm capitalize text-muted-foreground">{agreement.client_type}</p>
          </div>
        </div>
      </header>

      <main className="container mx-auto p-4 lg:p-8">
        <div className="mb-8">
            <h1 className="text-3xl font-bold tracking-tight md:text-4xl">Realizar Pedido</h1>
            <p className="mt-2 text-lg text-muted-foreground">Selecciona los productos que deseas ordenar.</p>
        </div>
        
        <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          {products.map((product) => (
            <ProductCard key={product.id} product={product} />
          ))}
        </div>
      </main>

      <CartWidget agreement={agreement} />
    </div>
  );
}
