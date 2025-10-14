"use client";

import { cloneElement } from "react";
import { agreementFormConfig } from "../../agreements/_components/form-config";
import { clientFormConfig } from "./form-config";
import { EntityDialog } from "../../_components/entity-dialog";

export function CreateClientButton({ children }: { children: React.ReactElement }) {
    
    // The EntityDialog now handles the entire creation flow.
    // This component is now just a wrapper for that dialog.
    return (
        <EntityDialog formConfig={clientFormConfig} entity={undefined}>
            {children}
        </EntityDialog>
    );
}
