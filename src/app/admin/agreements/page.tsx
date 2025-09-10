import { PlusCircle } from "lucide-react";
import { Button } from "@/components/ui/button";
import { getAgreements } from "@/app/actions/admin.actions";
import { AgreementDialog } from "./_components/agreement-dialog";
import AgreementsTable from "./_components/agreements-table";

export default async function AgreementsPage() {
  const { data: agreements, error } = await getAgreements();

  if (error) {
    return <p className="text-destructive">{error.message}</p>;
  }

  return (
   <div className="grid flex-1 items-start gap-4 md:gap-8">
      <div className="flex items-center">
        <div className="ml-auto flex items-center gap-2">
          <AgreementDialog>
            <Button size="sm" className="h-8 gap-1">
              <PlusCircle className="h-3.5 w-3.5" />
              <span className="sr-only sm:not-sr-only sm:whitespace-nowrap">
                Add Agreement
              </span>
            </Button>
          </AgreementDialog>
        </div>
      </div>
      <AgreementsTable agreements={agreements ?? []} />
    </div>
  );
}
