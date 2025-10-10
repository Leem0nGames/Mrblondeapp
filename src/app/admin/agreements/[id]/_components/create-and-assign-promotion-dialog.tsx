
"use client";

import { useCallback } from "react";
import { promotionFormConfig } from "../../../promotions/_components/form-config";
import type { FormConfig } from "../../../_components/entity-dialog";
import { EntityDialog } from "../../../_components/entity-dialog";
import { assignMultiplePromotionsToAgreement } from "@/app/actions/admin.actions";
import type { Promotion } from "@/types";
import { useToast } from "@/hooks/use-toast";


export function CreateAndAssignPromotionDialog({ children, agreementId }: { children: React.ReactNode, agreementId: string }) {
    const { toast } = useToast();

    // This is the core of the "create and assign" logic.
    // It's a wrapper around the original upsert action.
    const upsertAndAssignAction = useCallback(async (payload: any) => {
        // 1. Create the promotion using the original form config's action
        const createResult = await promotionFormConfig.upsertAction(payload);
        
        if (createResult.error || !createResult.data) {
            return createResult; // Propagate the error to be shown in the form
        }
        
        const newPromotion: Promotion = createResult.data;

        // 2. If creation is successful, automatically assign it to the current agreement
        const assignResult = await assignMultiplePromotionsToAgreement({
            agreement_id: agreementId,
            promotion_ids: [newPromotion.id],
        });

        if (assignResult.error) {
            // This is an edge case, but we should handle it.
            // We show a toast because the form dialog is already closed on success.
            toast({
                title: "Promoción Creada, pero no Asignada",
                description: `La promoción "${newPromotion.name}" se creó, pero ocurrió un error al asignarla. Por favor, asígnala manualmente. Error: ${assignResult.error.message}`,
                variant: "destructive"
            });
        }
        
        // Return the original success result to close the dialog
        return createResult;
    }, [agreementId, toast]);
    
    // We create a *new* config object for the EntityDialog, overriding the upsertAction
    const createAndAssignFormConfig: FormConfig<any> = {
        ...promotionFormConfig,
        entityName: "Nueva Promoción", // Change the name for clarity
        upsertAction: upsertAndAssignAction,
    };

    return (
        <EntityDialog formConfig={createAndAssignFormConfig}>
            {children}
        </EntityDialog>
    );
}

