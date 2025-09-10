
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import { PageHeader } from "@/components/shared/page-header";

export default function SettingsPage() {
  return (
    <div className="grid flex-1 items-start gap-4 md:gap-8">
      <PageHeader
        title="Configuración"
        description="Configura los ajustes generales de la aplicación."
      />
      
      <Card>
        <CardHeader>
          <CardTitle>Ajustes Generales</CardTitle>
          <CardDescription>
            Aquí podrás configurar variables importantes para el funcionamiento de la app.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <form className="space-y-4 max-w-lg">
            <div className="space-y-2">
              <Label htmlFor="whatsapp">Número de WhatsApp</Label>
              <Input 
                id="whatsapp"
                placeholder="e.g., 5491123456789"
                defaultValue={process.env.NEXT_PUBLIC_WHATSAPP_NUMBER}
              />
              <p className="text-xs text-muted-foreground">
                Este es el número al que se enviarán los resúmenes de pedido.
              </p>
            </div>
             <Button disabled>Guardar Cambios (Próximamente)</Button>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
