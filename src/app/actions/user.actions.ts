"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export async function login(formData: FormData) {
  const pin = formData.get("pin") as string;
  const adminPin = process.env.ADMIN_PIN || '1234';

  if (pin === adminPin) {
    const supabase = createClient();
    // This is a workaround to create a session for a "dummy" admin user.
    // In a real application, you'd have a proper user management system.
    const { error } = await supabase.auth.signInWithPassword({
      email: process.env.ADMIN_EMAIL!,
      password: process.env.ADMIN_PASSWORD!,
    });

    if (error) {
      return { error: { message: "Credenciales de administrador base no configuradas." } };
    }

    revalidatePath("/", "layout");
    
    if (pin === '1234') {
        // We can't redirect to a dedicated "change PIN" page yet,
        // as that page doesn't exist. For now, we'll just log in.
        // This is where you would redirect to a page to force a PIN change.
        // redirect('/admin/change-pin');
    }

    redirect("/admin");
  }

  return { error: { message: "PIN incorrecto." } };
}

export async function logout() {
  const supabase = createClient();
  await supabase.auth.signOut();
  redirect("/login");
}

export async function getOrderPageData(token: string) {
    const supabase = createClient();

    // 1. Verify token
    const { data: agreement, error: agreementError } = await supabase
        .from('agreements')
        .select('*')
        .eq('token', token)
        .single();

    if (agreementError || !agreement) {
        return { error: { message: "El enlace no es válido o ha expirado." } };
    }
    
    const now = new Date();
    const expiresAt = new Date(agreement.expires_at!);
    if (now > expiresAt) {
        return { error: { message: "El enlace ha expirado." } };
    }
    
    // 2. Fetch products
    const { data: products, error: productsError } = await supabase
        .from('products')
        .select('*')
        .order('name', { ascending: true });
        
    if (productsError) {
        return { error: { message: "No se pudieron cargar los productos." } };
    }

    return { data: { agreement, products: products ?? [] }, error: null };
}
