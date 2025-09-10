"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import type { Product } from "@/types";

type UpsertProductPayload = Omit<Product, "id" | "created_at"> & {
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

  if (error) {
    return { data: null, error };
  }

  revalidatePath("/admin/products");
  return { data, error: null };
}

export async function deleteProduct(id: string) {
  const supabase = await getAuthenticatedClient();

  const { error } = await supabase.from("products").delete().eq("id", id);
  
  if (error) {
    return { error };
  }

  revalidatePath("/admin/products");
  return { error: null };
}

export async function generateOrderLink(clientType: 'barberia' | 'distribuidor', clientName: string) {
  const supabase = await getAuthenticatedClient();

  const token = crypto.randomUUID();
  const expires_at = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();

  const { data, error } = await supabase
    .from('agreements')
    .insert({
      client_name: clientName,
      client_type: clientType,
      token,
      expires_at,
    })
    .select()
    .single();

  if (error) {
    return { link: null, error };
  }
  
  const host = process.env.NEXT_PUBLIC_HOST_URL || process.env.VERCEL_URL || 'localhost:9002';
  const protocol = host.startsWith('localhost') ? 'http' : 'https';
  const link = `${protocol}://${host}/pedido/${token}`;

  return { link, error: null };
}
