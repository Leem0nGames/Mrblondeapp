
"use client";

import { useTransition } from "react";
import type { Order } from "@/types";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import { Check } from "lucide-react";
import { completeOrder } from "@/app/actions/admin.actions";
import { useToast } from "@/hooks/use-toast";
import { Badge } from "@/components/ui/badge";

const formatCurrency = (value: number) => {
    return new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS' }).format(value);
}

export function RecentOrders({ orders }: { orders: Order[] }) {
    const [isPending, startTransition] = useTransition();
    const { toast } = useToast();

    // In a real app, this would be fetched, not hardcoded.
    const currentTotalRevenue = 123456.78; 

    const handleCompleteOrder = (orderId: string, orderTotal: number) => {
        startTransition(async () => {
            const result = await completeOrder(orderId, currentTotalRevenue, orderTotal);
            if (result.error) {
                toast({
                    title: "Error",
                    description: "No se pudo completar el pedido.",
                    variant: "destructive"
                });
            } else {
                toast({
                    title: "Éxito",
                    description: "Pedido marcado como completado."
                });
            }
        });
    }

    if (orders.length === 0) {
        return (
            <div className="text-center text-muted-foreground py-8">
                <p>No hay pedidos pendientes.</p>
            </div>
        )
    }

    return (
        <div className="space-y-8">
            {orders.map((order) => (
                <div key={order.id} className="flex items-center">
                    <Avatar className="h-9 w-9">
                        <AvatarImage src={`https://avatar.vercel.sh/${order.client_id}.png`} alt="Avatar" />
                        <AvatarFallback>{order.client_name_cache.charAt(0)}</AvatarFallback>
                    </Avatar>
                    <div className="ml-4 space-y-1">
                        <p className="text-sm font-medium leading-none">
                            {order.client_name_cache}
                        </p>
                        <p className="text-sm text-muted-foreground">
                            Pedido #{order.id.slice(-6)}
                        </p>
                    </div>
                    <div className="ml-auto font-medium text-right">
                       <p>{formatCurrency(order.total_amount)}</p>
                       <Badge variant="outline" className="mt-1">Pendiente</Badge>
                    </div>
                    <Button 
                        variant="outline" 
                        size="icon" 
                        className="ml-4 h-8 w-8 shrink-0"
                        onClick={() => handleCompleteOrder(order.id, order.total_amount)}
                        disabled={isPending}
                    >
                        <Check className="h-4 w-4" />
                        <span className="sr-only">Marcar como completado</span>
                    </Button>
                </div>
            ))}
        </div>
    );
}
