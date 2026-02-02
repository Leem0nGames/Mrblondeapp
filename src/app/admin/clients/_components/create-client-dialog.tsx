
"use client";

import React from "react";
import { UpsertClientDialog } from "./upsert-client-dialog";

export function CreateClientDialog({ children }: { children: React.ReactNode }) {
  // This component now simply acts as a trigger for the unified UpsertClientDialog
  // in "create" mode (by passing `client={undefined}`).
  return (
    <UpsertClientDialog client={undefined}>
        {children}
    </UpsertClientDialog>
  );
}
