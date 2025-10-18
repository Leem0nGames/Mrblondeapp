import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { PageHeader } from "@/components/shared/page-header";
import { getSettings } from "@/app/admin/actions/settings.actions";
import { SettingsForm } from "./_components/settings-form";

export default async function SettingsPage() {
  const settings = await getSettings();

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
          <SettingsForm settings={settings} />
        </CardContent>
      </Card>
    </div>
  );
}
