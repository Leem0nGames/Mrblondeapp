
"use server";

import { revalidatePath } from "next/cache";
import { getSupabaseClientWithAuth, upsertEntity, deleteEntity } from "./_helpers";

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
      id: id || undefined,
      name,
      description,
      category,
      image_url: finalImageUrl
  };
  
  const revalidatePaths = ["/admin/products", "/admin/pricelists"];
  
  return await upsertEntity("products", productData, revalidatePaths);
}

export async function deleteProduct(id: string) {
  return await deleteEntity("products", id, ["/admin/products", "/admin/pricelists"]);
}
