"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import type { Product, Agreement, Promotion } from "@/types";

type UpsertProductPayload = Omit<Product, "id" | "created_at"> & {
  id?: string;
};

type UpsertAgreementPayload = Pick<Agreement, "agreement_name" | "client_type"> & {
  id?: string;
};

type UpsertPromotionPayload = Omit<Promotion, "id" | "created_at" | "rules"> & {
  id?: string;
  rules: any;
};

// Helper function to ensure user is authenticated and the Supabase client is fresh.
// It will be called at the start of every action.
async function checkAuth() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    throw new Error("You must be logged in to perform this action.");
  }
  return user;
}


// --- Product Actions ---

export async function getProducts() {
  await checkAuth();
  const supabase = createClient();
  const { data, error } = await supabase.from("products").select("*").order("name", { ascending: true });
  if (error) {
    console.error("getProducts error:", error.message);
    throw error;
  }
  return { data, error };
}

export async function upsertProduct(payload: UpsertProductPayload) {
  await checkAuth();
  const supabase = createClient();
  const { id, ...productData } = payload;
  
  const query = supabase.from("products");

  const { data, error } = id
    ? await query.update(productData).eq("id", id).select().single()
    : await query.insert(productData).select().single();

  if (error) { 
    console.error("upsertProduct error:", error.message);
    return { data: null, error }; 
  }

  revalidatePath("/admin/products");
  return { data, error: null };
}

export async function deleteProduct(id: string) {
  await checkAuth();
  const supabase = createClient();
  const { error } = await supabase.from("products").delete().eq("id", id);
  if (error) { 
    console.error("deleteProduct error:", error.message);
    return { error }; 
  }
  revalidatePath("/admin/products");
  return { error: null };
}

// --- Agreement Actions ---

export async function getAgreements() {
  await checkAuth();
  const supabase = createClient();
  const { data, error } = await supabase
    .from("agreements")
    .select(`
      id,
      agreement_name,
      client_type,
      agreement_products ( count ),
      agreement_promotions ( count )
    `)
    .order("agreement_name", { ascending: true });
  if (error) {
    console.error("getAgreements error:", error.message);
    throw error;
  };
  return { data, error };
}

export async function getAgreementById(id: string) {
    await checkAuth();
    const supabase = createClient();
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
    if (error) {
        console.error("getAgreementById error:", error.message);
        throw error;
    }
    return { data, error };
}


export async function upsertAgreement(payload: UpsertAgreementPayload) {
  await checkAuth();
  const supabase = createClient();
  const { id, ...agreementData } = payload;

  const query = supabase.from("agreements");

  const { data, error } = id
    ? await query.update(agreementData).eq("id", id).select().single()
    : await query.insert(agreementData).select().single();

  if (error) {
    console.error("upsertAgreement error:", error.message);
    if (error.code === '23505') {
        return { data: null, error: { ...error, message: `Error: El nombre del convenio '${agreementData.agreement_name}' ya existe.` } };
    }
    return { data: null, error };
  }

  revalidatePath("/admin/agreements");
  return { data, error: null };
}

export async function deleteAgreement(id: string) {
    await checkAuth();
    const supabase = createClient();
    const { error } = await supabase.from("agreements").delete().eq("id", id);
    if (error) {
      console.error("deleteAgreement error:", error.message);
      return { error }; 
    }
    revalidatePath("/admin/agreements");
    return { error: null };
}

// --- Promotion Actions ---

export async function getPromotions() {
  await checkAuth();
  const supabase = createClient();
  const { data, error } = await supabase.from("promotions").select("*").order("name", { ascending: true });
  if (error) {
    console.error("getPromotions error:", error.message);
    throw error;
  }
  return { data, error };
}

export async function upsertPromotion(payload: UpsertPromotionPayload) {
  await checkAuth();
  const supabase = createClient();
  const { id, ...promoData } = payload;
  
  const query = supabase.from("promotions");
  const { data, error } = id
    ? await query.update(promoData).eq("id", id).select().single()
    : await query.insert(promoData).select().single();
    
  if (error) {
    console.error("upsertPromotion error:", error.message);
    return { data: null, error }; 
  }

  revalidatePath("/admin/promotions");
  revalidatePath("/admin/agreements");
  return { data, error: null };
}

export async function deletePromotion(id: string) {
  await checkAuth();
  const supabase = createClient();
  const { error } = await supabase.from("promotions").delete().eq("id", id);
  if (error) { 
    console.error("deletePromotion error:", error.message);
    return { error };
  }
  revalidatePath("/admin/promotions");
  revalidatePath("/admin/agreements");
  return { error: null };
}

// --- Agreement Product & Promotion Management ---

export async function getUnassignedProducts(agreementId: string) {
    await checkAuth();
    const supabase = createClient();
    const { data: assignedProductIds, error: assignedIdsError } = await supabase
        .from('agreement_products')
        .select('product_id')
        .eq('agreement_id', agreementId);

    if (assignedIdsError) {
      console.error("getUnassignedProducts (assigned) error:", assignedIdsError.message);
      return { data: [], error: assignedIdsError };
    }

    const assignedIds = assignedProductIds.map(p => p.product_id);
    
    if (assignedIds.length === 0) {
      const { data, error } = await supabase.from('products').select('*').order('name');
      if (error) {
        console.error("getUnassignedProducts (all) error:", error.message);
        throw error;
      }
      return { data, error };
    }

    const { data, error } = await supabase
        .from('products')
        .select('*')
        .not('id', 'in', `(${assignedIds.join(',')})`)
        .order('name');
    
    if (error) {
        console.error("getUnassignedProducts (filtered) error:", error.message);
        throw error;
    }
    return { data, error };
}

export async function getUnassignedPromotions(agreementId: string) {
    await checkAuth();
    const supabase = createClient();
    const { data: assignedPromotionIds, error: assignedIdsError } = await supabase
        .from('agreement_promotions')
        .select('promotion_id')
        .eq('agreement_id', agreementId);

    if (assignedIdsError) {
      console.error("getUnassignedPromotions (assigned) error:", assignedIdsError.message);
      return { data: [], error: assignedIdsError };
    }

    const assignedIds = assignedPromotionIds.map(p => p.promotion_id);

    if (assignedIds.length === 0) {
        const { data, error } = await supabase.from('promotions').select('*').order('name');
        if (error) {
            console.error("getUnassignedPromotions (all) error:", error.message);
            throw error;
        }
        return { data, error };
    }

    const { data, error } = await supabase
        .from('promotions')
        .select('*')
        .not('id', 'in', `(${assignedIds.join(',')})`)
        .order('name');
    
    if (error) {
        console.error("getUnassignedPromotions (filtered) error:", error.message);
        throw error;
    }
    return { data, error };
}


export async function assignProductToAgreement(payload: { agreement_id: string; product_id: string; price: number; }) {
    await checkAuth();
    const supabase = createClient();
    const { error } = await supabase.from('agreement_products').insert(payload);
    if (error) {
      console.error("assignProductToAgreement error:", error.message);
      return { error };
    }
    revalidatePath(`/admin/agreements/${payload.agreement_id}`);
    return { error: null };
}

export async function unassignProductFromAgreement(payload: { agreement_id: string; product_id: string; }) {
    await checkAuth();
    const supabase = createClient();
    const { error } = await supabase.from('agreement_products')
        .delete()
        .eq('agreement_id', payload.agreement_id)
        .eq('product_id', payload.product_id);

    if (error) {
      console.error("unassignProductFromAgreement error:", error.message);
      return { error };
    }
    revalidatePath(`/admin/agreements/${payload.agreement_id}`);
    return { error: null };
}

export async function updateAgreementProductPrice(payload: { agreement_id: string; product_id: string; price: number; }) {
    await checkAuth();
    const supabase = createClient();
    const { error } = await supabase.from('agreement_products')
        .update({ price: payload.price })
        .eq('agreement_id', payload.agreement_id)
        .eq('product_id', payload.product_id);

    if (error) {
      console.error("updateAgreementProductPrice error:", error.message);
      return { error };
    }
    revalidatePath(`/admin/agreements/${payload.agreement_id}`);
    return { error: null };
}


export async function assignPromotionToAgreement(payload: { agreement_id: string; promotion_id: string; }) {
    await checkAuth();
    const supabase = createClient();
    const { error } = await supabase.from('agreement_promotions').insert(payload);
    if (error) {
      console.error("assignPromotionToAgreement error:", error.message);
      return { error };
    }
    revalidatePath(`/admin/agreements/${payload.agreement_id}`);
    return { error: null };
}

export async function unassignPromotionFromAgreement(payload: { agreement_id: string; promotion_id: string; }) {
    await checkAuth();
    const supabase = createClient();
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
