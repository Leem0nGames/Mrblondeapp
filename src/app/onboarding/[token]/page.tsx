
import { getOnboardingClient } from "@/app/actions/user.actions";
import { getPublicLogoUrl } from "@/app/admin/actions/settings.actions";
import { Logo } from "@/app/logo";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { AlertTriangle } from "lucide-react";
import { Suspense } from "react";
import { OnboardingWrapper } from "./_components/onboarding-wrapper";


export default async function OnboardingPage({ params }: { params: { token: string } }) {
  const { data: client, error } = await getOnboardingClient(params.token);
  const logoUrl = await getPublicLogoUrl();

  if (error || !client) {
    return (
      <div className="flex h-screen flex-col items-center justify-center bg-background p-8 text-center">
        <div className="mb-8">
          <Logo showText={true} logoUrl={logoUrl} />
        </div>
        <Card className="max-w-md mt-8">
          <CardHeader>
            <CardTitle className="flex items-center justify-center gap-2 text-destructive">
              <AlertTriangle />
              Enlace Inválido
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-lg text-muted-foreground">{error?.message || "Este enlace de alta no es válido o ya ha sido utilizado."}</p>
            <p className="mt-2 text-sm text-muted-foreground">
              Por favor, solicita un nuevo enlace.
            </p>
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
     <div className="flex min-h-screen flex-col items-center justify-center bg-muted/20 p-4 md:p-8">
         <div className="mb-8">
            <Logo showText={true} logoUrl={logoUrl} />
        </div>
        <Card className="w-full max-w-3xl">
            <CardHeader>
                <CardTitle>¡Bienvenido/a, {client.contact_name}!</CardTitle>
                <CardDescription>
                    Estás a un solo paso de finalizar tu alta. Por favor, completa o verifica los siguientes datos.
                </CardDescription>
            </CardHeader>
            <CardContent>
                <Suspense fallback={<p>Cargando formulario...</p>}>
                    <OnboardingWrapper client={client} />
                </Suspense>
            </CardContent>
        </Card>
     </div>
  );
}
