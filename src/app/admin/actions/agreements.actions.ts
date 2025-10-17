
"use server";

import { revalidatePath } from "next/cache";
import { getSupabaseClientWithAuth, upsertEntity, deleteEntity } from "./_helpers";
import type { Agreement, DetailedAgreement, AgreementWithCount, AgreementSalesCondition } from "@/types";

// --- Agreement Actions ---

export async function getAgreements(): Promise<{ data: AgreementWithCount[] | null, error: any }> {
    const supabase = await getSupabaseClientWithAuth();
    
    const { data, error } = await supabase
        .from("agreements_with_counts")
        .select(`
            *,
            price_lists ( name )
        `)
        .order("agreement_name", { ascending: true });

    if (error) {
        console.error("getAgreements error:", error.message);
        return { data: null, error };
    }
    
    return { data: data as AgreementWithCount[], error: null };
}

export async function getAgreementById(id: string): Promise<{ data: DetailedAgreement | null, error: any }> {
    const supabase = await getSupabaseClientWithAuth();
    const { data, error } = await supabase
        .from("agreements")
        .select(`
            *,
            agreement_promotions (
                promotions ( * )
            ),
            agreement_sales_conditions (
              sales_conditions ( * )
            ),
            price_lists ( id, name, prices_include_vat ),
            clients ( id, contact_name )
        `)
        .eq("id", id)
        .maybeSingle();
    if (error) {
        console.error("getAgreementById error:", error.message);
        return { data: null, error };
    }
     if (!data) {
        return { data: null, error: { message: "Agreement not found." } };
    }
    const detailedAgreement: DetailedAgreement = {
        ...data,
        agreement_promotions: data.agreement_promotions ?? [],
        agreement_sales_conditions: data.agreement_sales_conditions ?? [],
        price_lists: data.price_lists,
        clients: data.clients ?? [],
    };
    return { data: detailedAgreement, error: null };
}

export async function getAgreementSalesConditions(agreementId: string): Promise<{ data: AgreementSalesCondition[] | null, error: any }> {
    const supabase = await getSupabaseClientWithAuth();
    const { data, error } = await supabase
        .from("agreement_sales_conditions")
        .select(`
            sales_conditions ( * )
        `)
        .eq("agreement_id", agreementId);

    if (error) {
        console.error("getAgreementSalesConditions error:", error.message);
        return { data: null, error };
    }
    return { data: data as AgreementSalesCondition[], error: null };
}

type UpsertAgreementPayload = Pick<Agreement, "agreement_name" | "client_type" | "price_list_id"> & {
  id?: string;
};

export async function upsertAgreement(payload: UpsertAgreementPayload) {
  const result = await upsertEntity("agreements", payload, ["/admin/agreements", "/admin/clients"]);
  if (result.error && result.error.code === '23505') {
    return { data: null, error: { ...result.error, message: `Error: El nombre del convenio '${payload.agreement_name}' ya existe.` } };
  }
  return result;
}

export async function deleteAgreement(id: string) {
    return await deleteEntity("agreements", id, ["/admin/agreements"]);
}

// --- Agreement Product & Promotion & Sales Condition Management ---

export async function getUnassignedPromotions(agreementId: string) {
    const supabase = await getSupabaseClientWithAuth();
    const { data: assignedPromotionIds, error: assignedIdsError } = await supabase
        .from('agreement_promotions')
        .select('promotion_id')
        .eq('agreement_id', agreementId);

    if (assignedIdsError) {
      console.error("getUnassignedPromotions (assigned) error:", assignedIdsError.message);
      return { data: [], error: assignedIdsError };
    }

    const assignedIds = assignedPromotionIds.map(p => p.promotion_id);

    const query = supabase.from('promotions').select('*').order('name');

    if (assignedIds.length > 0) {
        query.not('id', 'in', `(${assignedIds.join(',')})`)
    }

    const { data, error } = await query;
    
    if (error) {
        console.error("getUnassignedPromotions (filtered) error:", error.message);
        throw error;
    }
    return { data, error };
}

export async function assignMultiplePromotionsToAgreement(payload: {
  agreement_id: string;
  promotion_ids: string[];
}) {
  const supabase = await getSupabaseClientWithAuth();

  const promotionsToInsert = payload.promotion_ids.map(promoId => ({
    agreement_id: payload.agreement_id,
    promotion_id: promoId,
  }));

  const { error } = await supabase.from('agreement_promotions').insert(promotionsToInsert);

  if (error) {
    console.error("assignMultiplePromotionsToAgreement error:", error.message);
    return { error };
  }

  revalidatePath(`/admin/agreements/${payload.agreement_id}`);
  return { error: null };
}

export async function unassignPromotionFromAgreement(payload: { agreement_id: string; promotion_id: string; }) {
    const supabase = await getSupabaseClientWithAuth();
    const { error } = await supabase.from('agreement_promotions')
        .delete()
        .eq('agreement_id', payload.agreement_id)
        .eq('promotion_id', payload.promotion_id);

    if (error) {
      console.error("unassignPromotionFromAgreement error:", error.message);
      return { error };
    }
    revalidatePath(`/admin/agreements/${payload.agreement_id}`);
    return { error: null };
}

export async function getUnassignedSalesConditions(agreementId: string) {
    const supabase = await getSupabaseClientWithAuth();
    const { data: assignedIdsResult, error: assignedIdsError } = await supabase
        .from('agreement_sales_conditions')
        .select('sales_condition_id')
        .eq('agreement_id', agreementId);

    if (assignedIdsError) {
        console.error("getUnassignedSalesConditions (assigned) error:", assignedIdsError.message);
        return { data: [], error: assignedIdsError };
    }

    const assignedIds = assignedIdsResult.map(item => item.sales_condition_id);

    const query = supabase.from('sales_conditions').select('*').order('name');

    if (assignedIds.length > 0) {
        query.not('id', 'in', `(${assignedIds.join(',')})`)
    }

    const { data, error } = await query;

    if (error) {
        console.error("getUnassignedSalesConditions (filtered) error:", error.message);
        throw error;
    }
    return { data, error };
}

export async function assignMultipleSalesConditionsToAgreement(payload: {
    agreement_id: string;
    sales_condition_ids: string[];
}) {
    const supabase = await getSupabaseClientWithAuth();

    const conditionsToInsert = payload.sales_condition_ids.map(id => ({
        agreement_id: payload.agreement_id,
        sales_condition_id: id,
    }));

    const { error } = await supabase.from('agreement_sales_conditions').insert(conditionsToInsert);

    if (error) {
        console.error("assignMultipleSalesConditionsToAgreement error:", error.message);
        return { error };
    }

    revalidatePath(`/admin/agreements/${payload.agreement_id}`);
    return { error: null };
}

export async function unassignSalesConditionFromAgreement(payload: { agreement_id: string; sales_condition_id: string; }) {
    const supabase = await getSupabaseClientWithAuth();
    const { error } = await supabase.from('agreement_sales_conditions')
        .delete()
        .eq('agreement_id', payload.agreement_id)
        .eq('sales_condition_id', payload.sales_condition_id);

    if (error) {
        console.error("unassignSalesConditionFromAgreement error:", error.message);
        return { error };
    }
    revalidatePath(`/admin/agreements/${payload.agreement_id}`);
    return { error: null };
}
