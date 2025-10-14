

"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import type { Product, Agreement, Promotion, DetailedAgreement, AgreementWithCount, Client, PriceList, DetailedPriceList, PriceListItem, DashboardStats, Order, SalesCondition, ClientStats } from "@/types";

// --- Generic Helpers ---

async function getSupabaseClientWithAuth() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    throw new Error("You must be logged in to perform this action.");
  }
  return supabase;
}

async function upsertEntity(tableName: string, payload: { id?: string, [key: string]: any }, revalidatePaths: string[]) {
    const supabase = await getSupabaseClientWithAuth();
    const { id, ...data } = payload;
    
    const query = supabase.from(tableName);
    const { data: result, error } = id
        ? await query.update(data).eq("id", id).select().single()
        : await query.insert(data).select().single();

    if (error) {
        console.error(`upsertEntity error on table ${tableName}:`, error.message);
        return { data: null, error };
    }

    if (revalidatePaths.length > 0) {
        revalidatePaths.forEach(path => revalidatePath(path));
    }
    
    return { data: result, error: null };
}

async function deleteEntity(tableName: string, id: string, revalidatePaths: string[]) {
    const supabase = await getSupabaseClientWithAuth();
    
    const { error } = await supabase.from(tableName).delete().eq("id", id);
    
    if (error) {
        console.error(`deleteEntity error on table ${tableName}:`, error.message);
        return { error };
    }

    if (revalidatePaths.length > 0) {
        revalidatePaths.forEach(path => revalidatePath(path));
    }
    
    return { error: null };
}

// --- Product Actions ---

export async function getProducts() {
  const supabase = await getSupabaseClientWithAuth();
  const { data, error } = await supabase.from("products").select("*").order("name", { ascending: true });
  if (error) {
    console.error("getProducts error:", error.message);
    throw error;
  }
  return { data, error };
}

export async function upsertProduct(formData: FormData) {
  const supabase = await getSupabaseClientWithAuth();
  const id = formData.get('id') as string | null;
  const name = formData.get('name') as string;
  const description = formData.get('description') as string | null;
  const category = formData.get('category') as string | null;
  const imageFile = formData.get('image') as File | null;
  const image_url = formData.get('image_url') as string | null;
  
  let finalImageUrl = image_url;

  if (imageFile && imageFile.size > 0) {
    const fileExt = imageFile.name.split('.').pop();
    const fileName = `${id || crypto.randomUUID()}-${Date.now()}.${fileExt}`;
    const filePath = `products/${fileName}`;
    
    const { error: uploadError } = await supabase.storage
      .from('product_images')
      .upload(filePath, imageFile, { upsert: true });

    if (uploadError) {
      console.error("upsertProduct (upload) error:", uploadError.message);
      return { data: null, error: { message: "Error al subir la imagen." } };
    }

    const { data: publicUrlData } = supabase.storage
      .from('product_images')
      .getPublicUrl(filePath);

    finalImageUrl = publicUrlData.publicUrl;
  }
  
  const productData = {
      name,
      description,
      category,
      image_url: finalImageUrl
  };
  
  const query = supabase.from("products");
  const { data: result, error } = id
      ? await query.update(productData).eq("id", id).select().single()
      : await query.insert(productData).select().single();

  if (error) {
      console.error(`upsertProduct error:`, error.message);
      return { data: null, error };
  }

  revalidatePath("/admin/products");
  revalidatePath("/admin/pricelists");
  
  return { data: result, error: null };
}

export async function deleteProduct(id: string) {
  return await deleteEntity("products", id, ["/admin/products", "/admin/pricelists"]);
}

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


// --- Sales Condition Actions ---

export async function getSalesConditions() {
  const supabase = await getSupabaseClientWithAuth();
  const { data, error } = await supabase.from("sales_conditions").select("*").order("name", { ascending: true });
  if (error) {
    console.error("getSalesConditions error:", error.message);
    throw error;
  }
  return { data, error };
}

type UpsertSalesConditionPayload = Omit<SalesCondition, "id" | "created_at" | "rules"> & {
  id?: string;
  rules: any;
};

export async function upsertSalesCondition(payload: UpsertSalesConditionPayload) {
  return await upsertEntity("sales_conditions", payload, ["/admin/sales-conditions", "/admin/agreements"]);
}

export async function deleteSalesCondition(id: string) {
  return await deleteEntity("sales_conditions", id, ["/admin/sales-conditions", "/admin/agreements"]);
}

// --- Agreement Product & Promotion Management ---

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


// --- Agreement Sales Condition Management ---

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


// --- Client Actions ---
export async function getClients(): Promise<{ data: Client[] | null, error: any }> {
    const supabase = await getSupabaseClientWithAuth();
    
    const { data, error } = await supabase
        .from("clients")
        .select(`
            *,
            agreements ( agreement_name )
        `)
        .in('status', ['active', 'pending_agreement', 'pending_onboarding'])
        .order("created_at", { ascending: false });

    if (error) {
        console.error("getClients error:", error.message);
        return { data: null, error };
    }
    
    return { data, error: null };
}

export async function getClientById(id: string): Promise<{ data: Client | null, error: any }> {
    const supabase = await getSupabaseClientWithAuth();
    
    const { data, error } = await supabase
        .from("clients")
        .select(`
            *,
            agreements ( * )
        `)
        .eq('id', id)
        .single();
    
    if (error) {
        console.error("getClientById error:", error.message);
        return { data: null, error };
    }
    
    return { data, error: null };
}

export async function getClientStats(clientId: string): Promise<{ data: ClientStats | null, error: any }> {
    const supabase = await getSupabaseClientWithAuth();
    
    const { data, error } = await supabase
        .rpc('get_client_stats', { p_client_id: clientId })
        .single();

    if (error) {
        console.error("getClientStats error:", error.message);
        return { data: null, error };
    }
    
    return { data, error: null };
}

export async function createPlaceholderClient(): Promise<{ data: Client | null, error: any }> {
    const supabase = await getSupabaseClientWithAuth();
    
    // 1. Create a client with just the minimum required fields
    const { data: client, error } = await supabase
        .from('clients')
        .insert({
            status: 'pending_onboarding',
            onboarding_token: crypto.randomUUID(),
        })
        .select('id, onboarding_token')
        .single();

    if (error || !client) {
        console.error("createPlaceholderClient error:", error?.message);
        return { data: null, error: { message: 'No se pudo crear el cliente.' } };
    }

    // 2. Update the client with a descriptive placeholder name
    const placeholderName = `Cliente Pendiente #${client.id.slice(0, 4)}`;
    const { data: updatedClient, error: updateError } = await supabase
        .from('clients')
        .update({ contact_name: placeholderName })
        .eq('id', client.id)
        .select()
        .single();
    
    if (updateError) {
        console.error("createPlaceholderClient (update) error:", updateError.message);
        // If the update fails, we still have the client, but it's less descriptive.
        // We'll proceed but log the error.
    }

    revalidatePath("/admin/clients");
    return { data: updatedClient, error: null };
}

export async function assignAgreementToClient(payload: { clientId: string, agreementId: string | null }): Promise<{ error: any }> {
    const supabase = await getSupabaseClientWithAuth();

    const { data: client } = await supabase.from('clients').select('status').eq('id', payload.clientId).single();

    if (!client) {
        return { error: { message: 'Client not found.' } };
    }
    
    let newStatus = client.status;
    // Only change status if it makes sense. If a client is pending onboarding, they stay that way
    // even if an agreement is pre-assigned. They become active *after* onboarding.
    if (client.status === 'pending_agreement' && !payload.agreementId) {
        // This case is unlikely but handles removing an agreement before onboarding
        newStatus = 'pending_agreement';
    } else if (client.status === 'active' && !payload.agreementId) {
        // An active client with their agreement removed goes back to pending
        newStatus = 'pending_agreement';
    } else if (client.status === 'pending_agreement' && payload.agreementId) {
        // This client was waiting for an agreement, now they are active
        newStatus = 'active';
    }


    const { error } = await supabase
        .from("clients")
        .update({ 
            agreement_id: payload.agreementId,
            status: newStatus
        })
        .eq("id", payload.clientId);
    
    if (error) {
        console.error("assignAgreementToClient error:", error.message);
        return { error };
    }
    
    revalidatePath("/admin/clients");
    revalidatePath(`/admin/clients/${payload.clientId}`);
    revalidatePath("/admin");
    return { error: null };
}

export async function deleteClient(id: string) {
  const supabase = await getSupabaseClientWithAuth();
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
    const supabase = await getSupabaseClientWithAuth();
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
    const supabase = await getSupabaseClientWithAuth();
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
        .maybeSingle();
    if (error) {
        console.error("getPriceListById error:", error.message);
        return { data: null, error };
    }
    if (!data) {
        return { data: null, error: { message: "Price list not found." } };
    }
    const detailedPriceList: DetailedPriceList = {
        ...data,
        price_list_items: data.price_list_items ?? [],
    };
    return { data: detailedPriceList, error: null };
}

type UpsertPriceListPayload = { name: string, prices_include_vat: boolean, id?: string };
export async function upsertPriceList(payload: UpsertPriceListPayload) {
  const result = await upsertEntity("price_lists", payload, ["/admin/pricelists"]);
   if (result.error && result.error.code === '23505') { // Unique constraint violation
      return { data: null, error: { ...result.error, message: `El nombre '${payload.name}' ya existe.` } };
  }
  return result;
}

export async function deletePriceList(id: string) {
    return await deleteEntity("price_lists", id, ["/admin/pricelists"]);
}

export async function getUnassignedProductsForPriceList(priceListId: string) {
    const supabase = await getSupabaseClientWithAuth();
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
  const supabase = await getSupabaseClientWithAuth();
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
    const supabase = await getSupabaseClientWithAuth();
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
    const supabase = await getSupabaseClientWithAuth();
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
    const supabase = await getSupabaseClientWithAuth();
    
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
    const supabase = await getSupabaseClientWithAuth();
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

export async function getClientOrders(clientId: string): Promise<Order[]> {
    const supabase = await getSupabaseClientWithAuth();
    const { data, error } = await supabase
        .from("orders")
        .select("*")
        .eq("client_id", clientId)
        .order("created_at", { ascending: false });

    if (error) {
        console.error("getClientOrders error:", error.message);
        return [];
    }
    return data;
}

export async function getClientsWithPendingAgreements(): Promise<Client[]> {
    const supabase = await getSupabaseClientWithAuth();
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

export async function completeOrder(orderId: string, orderTotal: number) {
    const supabase = await getSupabaseClientWithAuth();
    
    // In a real app, this should be a single database transaction or an RPC call
    // to ensure atomicity. For this demo, we perform sequential operations.

    // 1. Mark the order as completed
    const { error: orderUpdateError } = await supabase
        .from('orders')
        .update({ status: 'completed' })
        .eq('id', orderId);

    if (orderUpdateError) {
        console.error("completeOrder (order) error:", orderUpdateError.message);
        return { error: orderUpdateError };
    }

    // 2. Increment the total_revenue in the stats table
    // This is not safe from race conditions. A DB function would be better.
    const { error: rpcError } = await supabase.rpc('increment_total_revenue', {
      amount_to_add: orderTotal
    });

    if (rpcError) {
        console.error("completeOrder (rpc) error:", rpcError.message);
        // In a real app, we might try to revert the order status update here.
        return { error: rpcError };
    }

    revalidatePath('/admin');
    return { error: null };
}

    
