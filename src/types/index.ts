// These types are manually created to match the Supabase schema.
// For a more robust solution, you can use `supabase gen types typescript`.

export type Product = {
  id: string;
  name: string;
  description: string | null;
  base_price: number;
  stock: number;
  category: string | null;
  created_at: string;
};

// A Product with an agreement-specific price.
// Used on the order page to ensure the correct price is used.
export type ProductWithPrice = Product & {
  price: number;
};

export type Promotion = {
  id: string;
  name: string;
  description: string | null;
  rules: any; // JSON object
  created_at: string;
};

// Represents a product specifically assigned to an agreement, with a custom price.
export type AgreementProduct = {
  agreement_id: string;
  product_id: string;
  price: number; // Custom price for this agreement
  products: Product; // Joined data from the products table
};

// Represents a promotion specifically assigned to an agreement.
export type AgreementPromotion = {
  agreement_id: string;
  promotion_id: string;
  promotions: Promotion; // Joined data from the promotions table
}

export type Agreement = {
  id: string;
  agreement_name: string;
  client_type: "barberia" | "distribuidor" | "especial";
  created_at: string;
};

// Type for the `agreements_with_counts` view
export type AgreementWithCount = Agreement & {
  product_count: number;
  promotion_count: number;
}


export type DetailedAgreement = Agreement & {
  agreement_products: AgreementProduct[]; // Joined data
  agreement_promotions: AgreementPromotion[]; // Joined data
}
