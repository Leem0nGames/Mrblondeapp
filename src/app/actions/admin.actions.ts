
"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import type { Product, Agreement, Promotion, DetailedAgreement, AgreementWithCount, Client, PriceList, DetailedPriceList, PriceListItem, DashboardStats, Order } from "@/types";

type UpsertProductPayload = Omit<Product, "id" | "created_at"> & {
  id?: string;
};

type UpsertAgreementPayload = Pick<Agreement, "agreement_name" | "client_type" | "price_list_id"> & {
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
  revalidatePath("/admin/pricelists");
  return { error: null };
}

// --- Agreement Actions ---

export async function getAgreements(): Promise<{ data: AgreementWithCount[] | null, error: any }> {
    await checkAuth();
    const supabase = createClient();
    
    const { data, error } = await supabase
        .from("agreements")
        .select(`
            *,
            agreement_promotions(count),
            price_lists ( name )
        `)
        .order("agreement_name", { ascending: true });

    if (error) {
        console.error("getAgreements error:", error.message);
        return { data: null, error };
    }

    // Manually map the data to the expected shape
    const agreementsWithCounts = data.map(agreement => ({
        ...agreement,
        promotion_count: agreement.agreement_promotions[0]?.count ?? 0,
    }));
    
    return { data: agreementsWithCounts, error: null };
}

export async function getAgreementById(id: string): Promise<{ data: DetailedAgreement | null, error: any }> {
    await checkAuth();
    const supabase = createClient();
    const { data, error } = await supabase
        .from("agreements")
        .select(`
            *,
            agreement_promotions (
                promotions ( * )
            ),
            price_lists ( id, name, prices_include_vat ),
            clients ( id, contact_name )
        `)
        .eq("id", id)
        .single();
    if (error) {
        console.error("getAgreementById error:", error.message);
        return { data: null, error };
    }
    // Ensure nested arrays are not null
    const detailedAgreement: DetailedAgreement = {
        ...data,
        agreement_promotions: data.agreement_promotions ?? [],
        price_lists: data.price_lists,
        clients: data.clients ?? [],
    };
    return { data: detailedAgreement, error: null };
}


export async function upsertAgreement(payload: UpsertAgreementPayload) {
  await checkAuth();
  const supabase = createClient();
  const { id, ...agreementData } = payload;

  const query = supabase.from("agreements");

  let data, error;
  
  if (id) {
    // Update existing agreement
    ({ data, error } = await query
      .update(agreementData)
      .eq("id", id)
      .select()
      .single());
  } else {
    // Create new agreement
    ({ data, error } = await query
      .insert(agreementData)
      .select()
      .single());
  }

  if (error) {
    console.error("upsertAgreement error:", error.message);
    if (error.code === '23505') { // Handle unique constraint violation for agreement_name
        return { data: null, error: { ...error, message: `Error: El nombre del convenio '${agreementData.agreement_name}' ya existe.` } };
    }
    return { data: null, error };
  }

  revalidatePath("/admin/agreements");
  revalidatePath("/admin/clients");
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
  await checkAuth();
  const supabase = createClient();

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


// --- Client Actions ---
export async function getClients(): Promise<{ data: Client[] | null, error: any }> {
    await checkAuth();
    const supabase = createClient();
    
    const { data, error } = await supabase
        .from("clients")
        .select(`
            *,
            agreements ( agreement_name )
        `)
        .in('status', ['active', 'pending_agreement', 'pending_onboarding'])
        .order("contact_name", { ascending: true });

    if (error) {
        console.error("getClients error:", error.message);
        return { data: null, error };
    }
    
    return { data, error: null };
}

export async function createClientOnboardingLink(): Promise<{ data: { onboarding_token: string } | null, error: any }> {
    await checkAuth();
    const supabase = createClient();

    const { data, error } = await supabase
        .from("clients")
        .insert({})
        .select("onboarding_token")
        .single();
    
    if (error) {
        console.error("createClientOnboardingLink error:", error.message);
        return { data: null, error };
    }
    
    revalidatePath("/admin/clients");
    return { data, error: null };
}

export async function assignAgreementToClient(payload: { clientId: string, agreementId: string | null }): Promise<{ error: any }> {
    await checkAuth();
    const supabase = createClient();

    const { error } = await supabase
        .from("clients")
        .update({ 
            agreement_id: payload.agreementId,
            status: payload.agreementId ? 'active' : 'pending_agreement' 
        })
        .eq("id", payload.clientId);
    
    if (error) {
        console.error("assignAgreementToClient error:", error.message);
        return { error };
    }
    
    revalidatePath("/admin/clients");
    revalidatePath("/admin");
    return { error: null };
}

export async function deleteClient(id: string) {
  await checkAuth();
  const supabase = createClient();
  const { error } = await supabase
    .from("clients")
    .update({ status: 'archived' })
    .eq("id", id);
    
  if (error) { 
    console.error("deleteClient (archive) error:", error.message);
    return { error }; 
  }
  revalidatePath("/admin/clients");
  return { error: null };
}

// --- Price List Actions ---

export async function getPriceLists(): Promise<{ data: PriceList[] | null, error: any }> {
    await checkAuth();
    const supabase = createClient();
    const { data, error } = await supabase
        .from("price_lists")
        .select('*')
        .order("name", { ascending: true });

    if (error) {
        console.error("getPriceLists error:", error.message);
        return { data: null, error };
    }
    return { data, error: null };
}

export async function getPriceListById(id: string): Promise<{ data: DetailedPriceList | null, error: any }> {
    await checkAuth();
    const supabase = createClient();
    const { data, error } = await supabase
        .from("price_lists")
        .select(`
            *,
            price_list_items (
                *,
                products ( * )
            )
        `)
        .eq("id", id)
        .single();
    if (error) {
        console.error("getPriceListById error:", error.message);
        return { data: null, error };
    }
    const detailedPriceList: DetailedPriceList = {
        ...data,
        price_list_items: data.price_list_items ?? [],
    };
    return { data: detailedPriceList, error: null };
}


export async function upsertPriceList(payload: { name: string, prices_include_vat: boolean, id?: string }) {
  await checkAuth();
  const supabase = createClient();
  const { id, ...priceListData } = payload;

  const query = supabase.from("price_lists");

  const { data, error } = id
    ? await query.update(priceListData).eq("id", id).select().single()
    : await query.insert(priceListData).select().single();

  if (error) {
    console.error("upsertPriceList error:", error.message);
    if (error.code === '23505') { // Unique constraint violation
        return { data: null, error: { ...error, message: `El nombre '${priceListData.name}' ya existe.` } };
    }
    return { data: null, error };
  }

  revalidatePath("/admin/pricelists");
  return { data, error: null };
}

export async function deletePriceList(id: string) {
    await checkAuth();
    const supabase = createClient();
    const { error } = await supabase.from("price_lists").delete().eq("id", id);
    if (error) {
      console.error("deletePriceList error:", error.message);
      return { error }; 
    }
    revalidatePath("/admin/pricelists");
    return { error: null };
}

export async function getUnassignedProductsForPriceList(priceListId: string) {
    await checkAuth();
    const supabase = createClient();
    const { data: assignedProductIds, error: assignedIdsError } = await supabase
        .from('price_list_items')
        .select('product_id')
        .eq('price_list_id', priceListId);

    if (assignedIdsError) {
      console.error("getUnassignedProductsForPriceList (assigned) error:", assignedIdsError.message);
      return { data: [], error: assignedIdsError };
    }

    const assignedIds = assignedProductIds.map(p => p.product_id);
    const query = supabase.from('products').select('*').order('name');
    if (assignedIds.length > 0) {
      query.not('id', 'in', `(${assignedIds.join(',')})`)
    }
    const { data, error } = await query;
    
    if (error) {
        console.error("getUnassignedProductsForPriceList (filtered) error:", error.message);
        throw error;
    }
    return { data, error };
}

export async function assignProductsToPriceList(payload: {
  price_list_id: string;
  products: { product_id: string; price: number, volume_price: number | null }[];
}) {
  await checkAuth();
  const supabase = createClient();
  const productsToInsert = payload.products.map(p => ({ ...p, price_list_id: payload.price_list_id }));
  const { error } = await supabase.from('price_list_items').insert(productsToInsert);

  if (error) {
    console.error("assignProductsToPriceList error:", error.message);
    return { error };
  }
  revalidatePath(`/admin/pricelists/${payload.price_list_id}`);
  return { error: null };
}

export async function unassignProductFromPriceList(payload: { price_list_id: string; product_id: string; }) {
    await checkAuth();
    const supabase = createClient();
    const { error } = await supabase.from('price_list_items')
        .delete()
        .eq('price_list_id', payload.price_list_id)
        .eq('product_id', payload.product_id);
    if (error) {
      console.error("unassignProductFromPriceList error:", error.message);
      return { error };
    }
    revalidatePath(`/admin/pricelists/${payload.price_list_id}`);
    return { error: null };
}

export async function updatePriceListItem(payload: { price_list_id: string; product_id: string; price: number; volume_price: number | null }) {
    await checkAuth();
    const supabase = createClient();
    const { price_list_id, product_id, ...updateData } = payload;
    const { error } = await supabase.from('price_list_items')
        .update(updateData)
        .eq('price_list_id', price_list_id)
        .eq('product_id', product_id);
    if (error) {
      console.error("updatePriceListItem error:", error.message);
      return { error };
    }
    revalidatePath(`/admin/pricelists/${price_list_id}`);
    return { error: null };
}


// --- Dashboard Actions ---

export async function getDashboardStats(): Promise<DashboardStats> {
    await checkAuth();
    const supabase = createClient();
    
    // For simplicity, we are fetching from a pre-aggregated table.
    // In a real app, you might have a cron job that updates this table.
    const { data, error } = await supabase.from("dashboard_stats").select("*").single();

    if (error || !data) {
        console.error("getDashboardStats error:", error?.message);
        // Return zeroed-out stats on error
        return {
            total_revenue: 0,
            month_revenue: 0,
            active_clients: 0
        };
    }
    return data;
}

export async function getPendingOrders(): Promise<Order[]> {
    await checkAuth();
    const supabase = createClient();
    const { data, error } = await supabase
        .from("orders")
        .select("*")
        .eq("status", "pending")
        .order("created_at", { ascending: false })
        .limit(5);

    if (error) {
        console.error("getPendingOrders error:", error.message);
        return [];
    }
    return data;
}

export async function getClientsWithPendingAgreements(): Promise<Client[]> {
    await checkAuth();
    const supabase = createClient();
    const { data, error } = await supabase
        .from("clients")
        .select("*")
        .eq("status", "pending_agreement")
        .order("created_at", { ascending: false });

    if (error) {
        console.error("getClientsWithPendingAgreements error:", error.message);
        return [];
    }
    return data;
}

export async function completeOrder(orderId: string, currentTotalRevenue: number, orderTotal: number) {
    await checkAuth();
    const supabase = createClient();
    
    const { error: orderUpdateError } = await supabase
        .from('orders')
        .update({ status: 'completed' })
        .eq('id', orderId);

    if (orderUpdateError) {
        console.error("completeOrder (order) error:", orderUpdateError.message);
        return { error: orderUpdateError };
    }

    // In a real app, this logic should be in a database trigger or a more robust
    // serverless function to prevent race conditions. For this demo, we update it here.
    const { error: statsUpdateError } = await supabase
        .from('dashboard_stats')
        .update({ 
            total_revenue: currentTotalRevenue + orderTotal,
         })
        .eq('id', 1); // Assuming single row for stats

     if (statsUpdateError) {
        console.error("completeOrder (stats) error:", statsUpdateError.message);
        // Note: The order is already marked as completed. We should handle this inconsistency.
        return { error: statsUpdateError };
    }

    revalidatePath('/admin');
    return { error: null };
}
