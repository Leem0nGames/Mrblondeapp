
"use server";

import { getSupabaseClientWithAuth, upsertEntity, deleteEntity } from "./_helpers";
import type { Promotion } from "@/types";

// --- Promotion Actions ---

export async function getPromotions() {
  const supabase = await getSupabaseClientWithAuth();
  const { data, error } = await supabase.from("promotions").select("*").order("name", { ascending: true });
  if (error) {
    console.error("getPromotions error:", error.message);
    throw error;
  }
  return { data, error };
}

type UpsertPromotionPayload = Omit<Promotion, "id" | "created_at" | "rules"> & {
  id?: string;
  rules: any;
};

export async function upsertPromotion(payload: UpsertPromotionPayload) {
  return await upsertEntity("promotions", payload, ["/admin/promotions", "/admin/agreements"]);
}

export async function deletePromotion(id: string) {
  return await deleteEntity("promotions", id, ["/admin/promotions", "/admin/agreements"]);
}
