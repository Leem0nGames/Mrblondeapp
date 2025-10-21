
"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";

// --- Generic Helpers ---

export async function getSupabaseClientWithAuth() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    throw new Error("You must be logged in to perform this action.");
  }
  return supabase;
}

export async function upsertEntity(tableName: string, payload: { id?: string, [key: string]: any }, revalidatePaths: string[]) {
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

export async function deleteEntity(tableName: string, id: string, revalidatePaths: string[]) {
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
