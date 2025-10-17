
"use client";

import dynamic from "next/dynamic";
import { Skeleton } from "@/components/ui/skeleton";
import type { Client, ClientStats, Order } from "@/types";

function ClientDetailsSkeleton() {
    return (
        <div className="grid flex-1 items-start gap-4 md:gap-8">
            <div className="flex items-center gap-4">
                <Skeleton className="h-7 w-7" />
                <Skeleton className="h-7 w-48" />
            </div>
            <Skeleton className="h-64 w-full" />
            <div className="grid gap-4 md:grid-cols-3">
                <Skeleton className="h-24" />
                <Skeleton className="h-24" />
                <Skeleton className="h-24" />
            </div>
            <div className="grid gap-4 md:grid-cols-3 md:gap-8">
                <Skeleton className="h-96 md:col-span-2" />
                <Skeleton className="h-96 md:col-span-1" />
            </div>
        </div>
    )
}

const ClientDetailsClient = dynamic(() => import('./client-details-client').then(mod => mod.ClientDetailsClient), {
  ssr: false,
  loading: () => <ClientDetailsSkeleton />,
});

type ClientDetailsLoaderProps = {
    client: Client;
    stats: ClientStats | null;
    orders: Order[];
}

export function ClientDetailsLoader(props: ClientDetailsLoaderProps) {
    return <ClientDetailsClient {...props} />
}
