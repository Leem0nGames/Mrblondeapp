"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import type { Product, Agreement } from "@/types";

type UpsertProductPayload = Omit<Product, "id" | "created_at"> & {
  id?: string;
};

// We only allow editing a subset of the agreement fields from the UI for now.
// The complex rules are managed elsewhere (e.g., AI prompt).
type UpsertAgreementPayload = Pick<Agreement, "name" | "client_type" | "price_adjustment"> & {
  id?: string;
};


// This is a helper function to ensure only authenticated users can perform admin actions.
async function getAuthenticatedClient() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    throw new Error("You must be logged in to perform this action.");
  }
  return supabase;
}

// --- Product Actions ---

export async function getProducts() {
  const supabase = await getAuthenticatedClient();
  const { data, error } = await supabase.from("products").select("*").order("created_at", { ascending: false });
  return { data, error };
}

export async function upsertProduct(payload: UpsertProductPayload) {
  const supabase = await getAuthenticatedClient();
  const { id, ...productData } = payload;
  
  const query = supabase.from("products");

  const { data, error } = id
    ? await query.update(productData).eq("id", id).select().single()
    : await query.insert(productData).select().single();

  if (error) { return { data: null, error }; }

  revalidatePath("/admin/products");
  return { data, error: null };
}

export async function deleteProduct(id: string) {
  const supabase = await getAuthenticatedClient();
  const { error } = await supabase.from("products").delete().eq("id", id);
  if (error) { return { error }; }
  revalidatePath("/admin/products");
  return { error: null };
}

// --- Agreement Actions ---

export async function getAgreements() {
  const supabase = await getAuthenticatedClient();
  const { data, error } = await supabase.from("agreements").select("*").order("name", { ascending: true });
  return { data, error };
}

export async function upsertAgreement(payload: UpsertAgreementPayload) {
  const supabase = await getAuthenticatedClient();
  const { id, ...agreementData } = payload;

  // The 'promo_override' field is complex and not managed by this simple form.
  // We set it to null or keep its existing value if we were to extend this logic.
  // For now, we just upsert the data from the form.
  const payloadToUpsert = { ...agreementData, promo_override: null };

  const query = supabase.from("agreements");
  const { data, error } = id
    ? await query.update(payloadToUpsert).eq("id", id).select().single()
    : await query.insert(payloadToUpsert).select().single();
  
  if (error) { return { data: null, error }; }

  revalidatePath("/admin/agreements");
  return { data, error: null };
}

export async function deleteAgreement(id: string) {
    const supabase = await getAuthenticatedClient();
    const { error } = await supabase.from("agreements").delete().eq("id", id);
    if (error) { return { error }; }
    revalidatePath("/admin/agreements");
    return { error: null };
}


// --- Link Generation ---
export async function generateOrderLink(agreementId: string, clientName: string) {
  const supabase = await getAuthenticatedClient();

  const token = crypto.randomUUID();
  const expires_at = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();

  const { data, error } = await supabase
    .from('access_tokens')
    .insert({
      agreement_id: agreementId,
      client_name: clientName,
      token,
      expires_at,
    })
    .select()
    .single();

  if (error) {
    return { link: null, error };
  }
  
  const host = process.env.NEXT_PUBLIC_HOST_URL || `https://${process.env.GITPOD_WORKSPACE_ID}.` || process.env.VERCEL_URL || 'localhost:9002';
  const protocol = host.startsWith('localhost') ? 'http' : 'https';
  const link = `${protocol}://${host}/pedido/${token}`;

  return { link, error: null };
}
