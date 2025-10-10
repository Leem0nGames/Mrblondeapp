
"use client";

import { useCallback } from "react";
import { salesConditionFormConfig } from "../../../sales-conditions/_components/form-config";
import type { FormConfig } from "../../../_components/entity-dialog";
import { EntityDialog } from "../../../_components/entity-dialog";
import { assignMultipleSalesConditionsToAgreement } from "@/app/actions/admin.actions";
import type { SalesCondition } from "@/types";
import { useToast } from "@/hooks/use-toast";


export function CreateAndAssignSalesConditionDialog({ children, agreementId }: { children: React.ReactNode, agreementId: string }) {
    const { toast } = useToast();

    // This is the core of the "create and assign" logic.
    // It's a wrapper around the original upsert action.
    const upsertAndAssignAction = useCallback(async (payload: any) => {
        // 1. Create the condition using the original form config's action
        const createResult = await salesConditionFormConfig.upsertAction(payload);
        
        if (createResult.error || !createResult.data) {
            return createResult; // Propagate the error to be shown in the form
        }
        
        const newCondition: SalesCondition = createResult.data;

        // 2. If creation is successful, automatically assign it to the current agreement
        const assignResult = await assignMultipleSalesConditionsToAgreement({
            agreement_id: agreementId,
            sales_condition_ids: [newCondition.id],
        });

        if (assignResult.error) {
            // This is an edge case, but we should handle it.
            // We show a toast because the form dialog is already closed on success.
            toast({
                title: "Condición Creada, pero no Asignada",
                description: `La condición "${newCondition.name}" se creó, pero ocurrió un error al asignarla. Por favor, asígnala manualmente. Error: ${assignResult.error.message}`,
                variant: "destructive"
            });
        }
        
        // Return the original success result to close the dialog
        return createResult;
    }, [agreementId, toast]);
    
    // We create a *new* config object for the EntityDialog, overriding the upsertAction
    const createAndAssignFormConfig: FormConfig<any> = {
        ...salesConditionFormConfig,
        entityName: "Nueva Condición de Venta", // Change the name for clarity
        upsertAction: upsertAndAssignAction,
    };

    return (
        <EntityDialog formConfig={createAndAssignFormConfig}>
            {children}
        </EntityDialog>
    );
}

