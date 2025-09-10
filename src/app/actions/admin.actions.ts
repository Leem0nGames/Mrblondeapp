"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import type { Product, Agreement, Client, Promotion } from "@/types";

type UpsertProductPayload = Omit<Product, "id" | "created_at"> & {
  id?: string;
};

type UpsertAgreementPayload = Pick<Agreement, "agreement_name" | "client_type" | "price_adjustment"> & {
  id?: string;
};

type UpsertClientPayload = Omit<Client, "id" | "created_at"> & {
  id?: string;
};

type UpsertPromotionPayload = Omit<Promotion, "id" | "created_at"> & {
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
  const { data, error } = await supabase
    .from("agreements")
    .select(`
      *,
      agreement_products (
        price,
        products ( * )
      ),
      agreement_promotions (
        promotions ( * )
      )
    `)
    .order("agreement_name", { ascending: true });
  return { data, error };
}

export async function getAgreementById(id: string) {
    const supabase = await getAuthenticatedClient();
    const { data, error } = await supabase
        .from("agreements")
        .select(`
            *,
            agreement_products (
                price,
                product_id,
                products ( * )
            ),
            agreement_promotions (
                promotion_id,
                promotions ( * )
            )
        `)
        .eq("id", id)
        .single();
    return { data, error };
}


export async function upsertAgreement(payload: UpsertAgreementPayload) {
  const supabase = await getAuthenticatedClient();
  const { id, ...agreementData } = payload;
  
  const query = supabase.from("agreements");
  const { data, error } = id
    ? await query.update(agreementData).eq("id", id).select().single()
    : await query.insert(agreementData).select().single();
  
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

// --- Client Actions ---

export async function getClients() {
  const supabase = await getAuthenticatedClient();
  const { data, error } = await supabase.from("clients").select("*").order("name", { ascending: true });
  return { data, error };
}

export async function upsertClient(payload: UpsertClientPayload) {
  const supabase = await getAuthenticatedClient();
  const { id, ...clientData } = payload;
  
  const query = supabase.from("clients");
  const { data, error } = id
    ? await query.update(clientData).eq("id", id).select().single()
    : await query.insert(clientData).select().single();
    
  if (error) { return { data: null, error }; }

  revalidatePath("/admin/clients");
  return { data, error: null };
}

export async function deleteClient(id: string) {
  const supabase = await getAuthenticatedClient();
  const { error } = await supabase.from("clients").delete().eq("id", id);
  if (error) { return { error }; }
  revalidatePath("/admin/clients");
  return { error: null };
}


// --- Promotion Actions ---

export async function getPromotions() {
  const supabase = await getAuthenticatedClient();
  const { data, error } = await supabase.from("promotions").select("*").order("name", { ascending: true });
  return { data, error };
}

export async function upsertPromotion(payload: UpsertPromotionPayload) {
  const supabase = await getAuthenticatedClient();
  const { id, ...promoData } = payload;
  
  const query = supabase.from("promotions");
  const { data, error } = id
    ? await query.update(promoData).eq("id", id).select().single()
    : await query.insert(promoData).select().single();
    
  if (error) { return { data: null, error }; }

  revalidatePath("/admin/promotions");
  return { data, error: null };
}

export async function deletePromotion(id: string) {
  const supabase = await getAuthenticatedClient();
  const { error } = await supabase.from("promotions").delete().eq("id", id);
  if (error) { return { error }; }
  revalidatePath("/admin/promotions");
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

// --- Agreement Product & Promotion Management ---

export async function getUnassignedProducts(agreementId: string) {
    const supabase = await getAuthenticatedClient();
    const { data: assignedProductIds, error: assignedIdsError } = await supabase
        .from('agreement_products')
        .select('product_id')
        .eq('agreement_id', agreementId);

    if (assignedIdsError) return { data: [], error: assignedIdsError };

    const assignedIds = assignedProductIds.map(p => p.product_id);

    const { data, error } = await supabase
        .from('products')
        .select('*')
        .not('id', 'in', `(${assignedIds.join(',')})`)
        .order('name');
    
    return { data, error };
}

export async function getUnassignedPromotions(agreementId: string) {
    const supabase = await getAuthenticatedClient();
    const { data: assignedPromotionIds, error: assignedIdsError } = await supabase
        .from('agreement_promotions')
        .select('promotion_id')
        .eq('agreement_id', agreementId);

    if (assignedIdsError) return { data: [], error: assignedIdsError };

    const assignedIds = assignedPromotionIds.map(p => p.promotion_id);

    const { data, error } = await supabase
        .from('promotions')
        .select('*')
        .not('id', 'in', `(${assignedIds.join(',')})`)
        .order('name');
    
    return { data, error };
}


export async function assignProductToAgreement(payload: { agreement_id: string; product_id: string; price: number; }) {
    const supabase = await getAuthenticatedClient();
    const { error } = await supabase.from('agreement_products').insert(payload);
    if (error) return { error };
    revalidatePath(`/admin/agreements/${payload.agreement_id}`);
    return { error: null };
}

export async function unassignProductFromAgreement(payload: { agreement_id: string; product_id: string; }) {
    const supabase = await getAuthenticatedClient();
    const { error } = await supabase.from('agreement_products')
        .delete()
        .eq('agreement_id', payload.agreement_id)
        .eq('product_id', payload.product_id);

    if (error) return { error };
    revalidatePath(`/admin/agreements/${payload.agreement_id}`);
    return { error: null };
}

export async function updateAgreementProductPrice(payload: { agreement_id: string; product_id: string; price: number; }) {
    const supabase = await getAuthenticatedClient();
    const { error } = await supabase.from('agreement_products')
        .update({ price: payload.price })
        .eq('agreement_id', payload.agreement_id)
        .eq('product_id', payload.product_id);

    if (error) return { error };
    revalidatePath(`/admin/agreements/${payload.agreement_id}`);
    return { error: null };
}


export async function assignPromotionToAgreement(payload: { agreement_id: string; promotion_id: string; }) {
    const supabase = await getAuthenticatedClient();
    const { error } = await supabase.from('agreement_promotions').insert(payload);
    if (error) return { error };
    revalidatePath(`/admin/agreements/${payload.agreement_id}`);
    return { error: null };
}

export async function unassignPromotionFromAgreement(payload: { agreement_id: string; promotion_id: string; }) {
    const supabase = await getAuthenticatedClient();
    const { error } = await supabase.from('agreement_promotions')
        .delete()
        .eq('agreement_id', payload.agreement_id)
        .eq('promotion_id', payload.promotion_id);

    if (error) return { error };
    revalidatePath(`/admin/agreements/${payload.agreement_id}`);
    return { error: null };
}
