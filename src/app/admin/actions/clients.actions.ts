
"use server";

import { revalidatePath } from "next/cache";
import { getSupabaseClientWithAuth } from "./_helpers";
import type { Client, ClientStats } from "@/types";

// --- Client Actions ---
export async function getClients(
  query?: string
): Promise<{ data: Client[] | null; error: any }> {
  const supabase = await getSupabaseClientWithAuth();

  let queryBuilder = supabase
    .from("clients")
    .select(
      `
            *,
            agreements ( agreement_name )
        `
    )
    .in("status", ["active", "pending_agreement", "pending_onboarding"])
    .order("created_at", { ascending: false });

  if (query) {
    const cleanedQuery = `%${query.replace(/\s/g, "%")}%`;
    queryBuilder = queryBuilder.or(
      `contact_name.ilike.${cleanedQuery},cuit.ilike.${cleanedQuery},address.ilike.${cleanedQuery}`
    );
  }

  const { data, error } = await queryBuilder;

  if (error) {
    console.error("getClients error:", error.message);
    return { data: null, error };
  }

  return { data, error: null };
}

export async function getClientById(
  id: string
): Promise<{ data: Client | null; error: any }> {
  const supabase = await getSupabaseClientWithAuth();

  const { data, error } = await supabase
    .from("clients")
    .select(
      `
            *,
            agreements ( * )
        `
    )
    .eq("id", id)
    .single();

  if (error) {
    console.error("getClientById error:", error.message);
    return { data: null, error };
  }

  return { data, error: null };
}

export async function getClientStats(
  clientId: string
): Promise<{ data: ClientStats | null; error: any }> {
  const supabase = await getSupabaseClientWithAuth();

  const { data, error } = await supabase
    .rpc("get_client_stats", { p_client_id: clientId })
    .single();

  if (error) {
    console.error("getClientStats error:", error.message);
    return { data: null, error };
  }

  return { data, error: null };
}

export async function createClientForInvitation(
  agreementId: string | null
): Promise<{ data: { link: string } | null; error: any }> {
  const supabase = await getSupabaseClientWithAuth();

  const placeholderName = `Cliente Pendiente - ${new Date().toISOString()}`;
  const onboardingToken = crypto.randomUUID();

  const { data: client, error } = await supabase
    .from("clients")
    .insert({
      status: "pending_onboarding",
      onboarding_token: onboardingToken,
      contact_name: placeholderName,
      agreement_id: agreementId,
    })
    .select("id")
    .single();

  if (error || !client) {
    console.error("createClientForInvitation error:", error?.message);
    return {
      data: null,
      error: { message: "No se pudo crear la invitación para el cliente." },
    };
  }

  // The revalidation is what's causing issues with cookies. We'll handle state update on the client.
  // revalidatePath("/admin/clients");

  const link = `/onboarding/${onboardingToken}`;
  return { data: { link }, error: null };
}

export async function createFullClient(
  payload: Omit<
    Client,
    "id" | "created_at" | "status" | "onboarding_token" | "agreements"
  > & {
    delivery_days: string[];
    delivery_time_from: string;
    delivery_time_to: string;
    street_address: string;
    street_number: string;
    locality: string;
    province: string;
  }
) {
  const supabase = await getSupabaseClientWithAuth();

  const {
    agreement_id,
    delivery_days,
    delivery_time_from,
    delivery_time_to,
    street_address,
    street_number,
    locality,
    province,
    ...clientData
  } = payload;

  const newStatus: Client["status"] = agreement_id
    ? "active"
    : "pending_agreement";

  const address = `${street_address} ${street_number}, ${locality}, ${province}`;
  const delivery_window = `${delivery_days.join(
    ", "
  )} de ${delivery_time_from} a ${delivery_time_to}hs`;

  const { data: newClient, error } = await supabase
    .from("clients")
    .insert({
      ...clientData,
      address,
      delivery_window,
      agreement_id: agreement_id,
      status: newStatus,
      onboarding_token: crypto.randomUUID(),
    })
    .select()
    .single();

  if (error) {
    console.error("createFullClient error:", error.message);
    if (error.code === "23505") {
      if (error.message.includes("cuit")) {
        return {
          error: {
            message: "El CUIT ingresado ya está registrado en nuestro sistema.",
          },
        };
      }
      if (error.message.includes("email")) {
        return {
          error: {
            message: "El email ingresado ya está registrado en nuestro sistema.",
          },
        };
      }
    }
    return { error };
  }

  revalidatePath("/admin/clients");
  revalidatePath("/admin");
  return { data: newClient, error: null };
}

export async function assignAgreementToClient(payload: {
  clientId: string;
  agreementId: string | null;
}): Promise<{ error: any }> {
  const supabase = await getSupabaseClientWithAuth();

  const { data: client, error: clientError } = await supabase
    .from("clients")
    .select("status")
    .eq("id", payload.clientId)
    .single();

  if (clientError || !client) {
    return { error: { message: "Client not found." } };
  }

  let newStatus = client.status as Client["status"];

  if (client.status !== "pending_onboarding") {
    newStatus = payload.agreementId ? "active" : "pending_agreement";
  }

  const { error } = await supabase
    .from("clients")
    .update({
      agreement_id: payload.agreementId,
      status: newStatus,
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
    .update({ status: "archived" })
    .eq("id", id);

  if (error) {
    console.error("deleteClient (archive) error:", error.message);
    return { error };
  }
  revalidatePath("/admin/clients");
  return { error: null };
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
