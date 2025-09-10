
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";

export default function SettingsPage() {
  return (
    <div className="grid flex-1 items-start gap-4 md:gap-8">
      <h1 className="text-2xl font-bold">Configuración</h1>
      
      <Card>
        <CardHeader>
          <CardTitle>Ajustes Generales</CardTitle>
          <CardDescription>
            Configura los ajustes generales de la aplicación.
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
