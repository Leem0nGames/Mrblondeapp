
"use client";

import { UpsertClientDialog } from "./upsert-client-dialog";

export function CreateClientDialog({ children }: { children: React.ReactNode }) {
  // This component is now just a trigger for the new unified dialog.
  // We pass `client={undefined}` to indicate that we are creating a new client.
  return (
    <UpsertClientDialog client={undefined}>
        {children}
    </UpsertClientDialog>
  );
}
