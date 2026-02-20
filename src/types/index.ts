
export type AuthState = {
  error: {
    message: string;
  } | null;
};

export type Product = {
  id: string;
  name: string;
  description: string | null;
  category: string | null;
  image_url: string | null;
  created_at: string;
};

export type ProductWithPrice = Product & {
  price: number;
  volume_price?: number | null;
};

export type CartItem = {
  product: ProductWithPrice;
  quantity: number;
};

export type { CartItem as CartItemType };

export type Promotion = {
  id: string;
  name: string;
  description: string | null;
  rules: any;
  created_at: string;
};

export type Order = {
    id: string;
    client_id: string | null;
    agreement_id: string;
    created_at: string;
    total_amount: number;
    status: 'armado' | 'transito' | 'entregado';
    client_name_cache: string;
    notes?: string | null;
}

export type OrderWithItems = Order & {
    order_items: {
        quantity: number;
        price_per_unit: number;
        products: {
            name: string;
            category: string | null;
        } | null;
    }[];
    clients?: Client | null;
}

export type Client = {
    id: string;
    contact_name: string | null;
    email: string | null;
    cuit: string | null;
    address: string | null;
    status: 'pending_onboarding' | 'pending_agreement' | 'active' | 'archived';
    onboarding_token: string | null;
    agreement_id: string | null;
    delivery_window: string | null;
}

export type DashboardStats = {
    total_revenue: number;
    month_revenue: number;
    active_clients: number;
    pending_orders_count: number;
    total_clients: number;
    total_pricelists: number;
    total_promotions: number;
    total_sales_conditions: number;
}

export type AppSettings = {
    whatsapp_number: string;
    vat_percentage: number;
    logo_url: string | null;
}

export type AppSettingsRow = {
    key: string;
    value: any;
};
