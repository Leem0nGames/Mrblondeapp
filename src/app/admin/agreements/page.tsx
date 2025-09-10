import { PlusCircle, FileWarning } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { getAgreements } from "@/app/actions/admin.actions";
import { AgreementDialog } from "./_components/agreement-dialog";
import { AgreementCard } from "./_components/agreement-card";

export default async function AgreementsPage() {
  const { data: agreements, error } = await getAgreements();

  if (error) {
    return <p className="text-destructive">{error.message}</p>;
  }

  return (
    <div className="grid flex-1 items-start gap-4 md:gap-8">
      <div className="flex items-center">
        <h1 className="text-2xl font-bold">Convenios</h1>
        <div className="ml-auto flex items-center gap-2">
          <AgreementDialog>
            <Button size="sm" className="h-8 gap-1">
              <PlusCircle className="h-3.5 w-3.5" />
              <span className="sr-only sm:not-sr-only sm:whitespace-nowrap">
                Agregar Convenio
              </span>
            </Button>
          </AgreementDialog>
        </div>
      </div>

      {agreements && agreements.length > 0 ? (
        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
          {agreements.map((agreement) => (
            <AgreementCard key={agreement.id} agreement={agreement} />
          ))}
        </div>
      ) : (
        <Card className="flex flex-col items-center justify-center py-12">
           <CardHeader className="text-center">
              <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-muted">
                <FileWarning className="h-6 w-6 text-muted-foreground" />
              </div>
              <CardTitle className="mt-4">No hay convenios</CardTitle>
              <CardDescription>
                Crea tu primer convenio para empezar a definir reglas de negocio.
              </CardDescription>
            </CardHeader>
             <CardContent>
                <AgreementDialog>
                  <Button>
                    <PlusCircle className="mr-2 h-4 w-4" />
                    Crear Convenio
                  </Button>
                </AgreementDialog>
            </CardContent>
        </Card>
      )}
    </div>
  );
}
