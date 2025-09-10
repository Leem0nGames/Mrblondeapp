import { PlusCircle } from "lucide-react";
import { Button } from "@/components/ui/button";
import { getClients } from "@/app/actions/admin.actions";
import { ClientDialog } from "./_components/client-dialog";
import ClientsTable from "./_components/clients-table";

export default async function ClientsPage() {
  const { data: clients, error } = await getClients();

  if (error) {
    return <p className="text-destructive">{error.message}</p>;
  }

  return (
   <div className="grid flex-1 items-start gap-4 md:gap-8">
      <div className="flex items-center">
        <div className="ml-auto flex items-center gap-2">
          <ClientDialog>
            <Button size="sm" className="h-8 gap-1">
              <PlusCircle className="h-3.5 w-3.5" />
              <span className="sr-only sm:not-sr-only sm:whitespace-nowrap">
                Add Client
              </span>
            </Button>
          </ClientDialog>
        </div>
      </div>
      <ClientsTable clients={clients ?? []} />
    </div>
  );
}
