
"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export async function login(formData: FormData) {
  const pin = formData.get("pin") as string;
  const supabase = createClient();
  
  // Estas son las credenciales fijas para el administrador, como se define en la lógica de negocio.
  const adminPin = process.env.ADMIN_PIN || "1234";
  const adminEmail = process.env.ADMIN_EMAIL || "admin@blonde.com";
  const adminPassword = process.env.ADMIN_PASSWORD || "admin1234";

  if (pin !== adminPin) {
    console.error("Login failed: Incorrect PIN provided.");
    return { error: { message: "PIN incorrecto." } };
  }

  const { error } = await supabase.auth.signInWithPassword({
    email: adminEmail,
    password: adminPassword,
  });

  if (error) {
    console.error("Supabase login error:", error.message);
    return { error: { message: "No se pudo autenticar al administrador. Verifique las credenciales o contacte al soporte." } };
  }

  // Si el login es exitoso, revalidamos la ruta y redirigimos.
  // Esto debe estar fuera de cualquier bloque try/catch que pueda interferir con la excepción que lanza redirect().
  revalidatePath("/", "layout");
  redirect("/admin");
}

export async function logout() {
  const supabase = createClient();
  await supabase.auth.signOut();
  redirect("/login");
}

export async function getOrderPageData(agreementId: string) {
    const supabase = createClient();

    const { data: agreement, error: agreementError } = await supabase
        .from('agreements')
        .select(`
            *,
            agreement_products(
                price,
                products(*)
            ),
            agreement_promotions(
                promotions(*)
            )
        `)
        .eq('id', agreementId)
        .single();

    if (agreementError || !agreement) {
        console.error("getOrderPageData (agreement) error:", agreementError?.message);
        return { data: null, error: { message: "El convenio no es válido o ha expirado." } };
    }
    
    // Filter out any products that might be null
    const validAgreementProducts = agreement.agreement_products.filter(ap => ap.products);

    const products = validAgreementProducts.map(ap => ({
        ...ap.products!,
        price: ap.price, // Override base_price with the agreement-specific price
    }));

    return { 
        data: { 
            agreement: {
                ...agreement,
                // Ensure promotions are always an array
                agreement_promotions: agreement.agreement_promotions ?? [],
            }, 
            products 
        }, 
        error: null 
    };
}
