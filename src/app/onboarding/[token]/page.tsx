
import { getOnboardingClient } from "@/app/actions/user.actions";
import { OnboardingForm } from "./_components/onboarding-form";
import { Logo } from "@/components/logo";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { AlertTriangle, CheckCircle } from "lucide-react";

export default async function OnboardingPage({ params }: { params: { token: string } }) {
  const { data: client, error } = await getOnboardingClient(params.token);

  if (error || !client) {
    return (
      <div className="flex h-screen flex-col items-center justify-center bg-background p-8 text-center">
        <div className="mb-8">
          <Logo showText={true} />
        </div>
        <Card className="max-w-md mt-8">
          <CardHeader>
            <CardTitle className="flex items-center justify-center gap-2 text-destructive">
              <AlertTriangle />
              Enlace Inválido o Expirado
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-lg text-muted-foreground">
              El enlace de invitación que utilizaste no es válido.
            </p>
            <p className="mt-2 text-sm text-muted-foreground">
              Por favor, solicita un nuevo enlace al administrador.
            </p>
          </CardContent>
        </Card>
      </div>
    );
  }

  if (client.status !== 'pending_onboarding') {
    return (
       <div className="flex h-screen flex-col items-center justify-center bg-background p-8 text-center">
        <div className="mb-8">
          <Logo showText={true} />
        </div>
        <Card className="max-w-md mt-8">
          <CardHeader>
            <CardTitle className="flex items-center justify-center gap-2 text-primary">
              <CheckCircle />
              ¡Ya estás registrado!
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-lg text-muted-foreground">
              Tus datos ya fueron completados.
            </p>
            <p className="mt-2 text-sm text-muted-foreground">
              Pronto recibirás tu enlace para realizar pedidos. ¡Gracias!
            </p>
          </CardContent>
        </Card>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-muted/40 py-8 px-4">
      <header className="container mx-auto max-w-2xl text-center mb-8">
        <div className="inline-block">
            <Logo showText={true} />
        </div>
      </header>
      <main className="container mx-auto max-w-2xl">
        <Card>
          <CardHeader>
            <CardTitle>Formulario de Alta de Cliente</CardTitle>
            <CardDescription>
              Completa tus datos para crear tu cuenta y acceder a los pedidos.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <OnboardingForm client={client} />
          </CardContent>
        </Card>
      </main>
    </div>
  );
}
