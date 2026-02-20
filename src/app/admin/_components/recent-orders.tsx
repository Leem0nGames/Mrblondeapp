
"use client";

import { useTransition, useState } from "react";
import type { Order } from "@/types";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import { Check, Printer, StickyNote } from "lucide-react";
import { updateOrderStatus } from "@/app/admin/actions/orders.actions";
import { useToast } from "@/hooks/use-toast";
import { Badge } from "@/components/ui/badge";
import { OrderNoteWidget } from "./order-note-widget";
import { Checkbox } from "@/components/ui/checkbox";
import { Input } from "@/components/ui/input";
import { ShippingLabelButton } from "./shipping-label-button";

const formatCurrency = (value: number) => {
    return new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS' }).format(value);
}

type NoteInfo = {
    clientName: string;
    note: string;
}

export function RecentOrders({ orders: initialOrders }: { orders: Order[] }) {
    const [isPending, startTransition] = useTransition();
    const { toast } = useToast();
    const [orders, setOrders] = useState(initialOrders);
    
    // Note Management
    const [activeNote, setActiveNote] = useState<NoteInfo | null>(null);
    const [minimizedNotes, setMinimizedNotes] = useState<NoteInfo[]>([]);

    // Printing/Selection State
    const [selectedOrders, setSelectedOrders] = useState<Record<string, boolean>>({});
    const [orderBundles, setOrderBundles] = useState<Record<string, number>>({});

    const handleUpdateStatus = (orderId: string, nextStatus: 'transito' | 'entregado') => {
        startTransition(async () => {
            const { error } = await updateOrderStatus(orderId, nextStatus);
            if (error) {
                toast({ title: "Error", description: "No se pudo actualizar el estado.", variant: "destructive" });
            } else {
                setOrders(current => current.filter(o => o.id !== orderId));
                toast({ title: "Estado Actualizado", description: `El pedido está ahora en ${nextStatus}.` });
            }
        });
    }

    const toggleSelection = (orderId: string) => {
        setSelectedOrders(prev => ({ ...prev, [orderId]: !prev[orderId] }));
        if (!orderBundles[orderId]) {
            setOrderBundles(prev => ({ ...prev, [orderId]: 1 }));
        }
    };

    const updateBundleCount = (orderId: string, count: number) => {
        setOrderBundles(prev => ({ ...prev, [orderId]: Math.max(1, count) }));
    };

    const selectedOrderList = Object.entries(selectedOrders)
        .filter(([_, isSelected]) => isSelected)
        .map(([id, _]) => ({ id, bundles: orderBundles[id] || 1 }));

    if (orders.length === 0) {
        return (
            <div className="text-center text-muted-foreground py-8">
                <p>No hay pedidos pendientes.</p>
            </div>
        )
    }

    return (
        <div className="relative">
            {selectedOrderList.length > 0 && (
                <div className="mb-6 p-4 bg-muted/50 rounded-lg flex items-center justify-between animate-in fade-in slide-in-from-top-2">
                    <p className="text-sm font-medium">{selectedOrderList.length} pedidos seleccionados para rótulos</p>
                    <ShippingLabelButton orders={selectedOrderList} />
                </div>
            )}

            <div className="space-y-6">
                {orders.map((order) => (
                    <div key={order.id} className="flex items-center gap-4 transition-opacity group">
                        <Checkbox 
                            checked={!!selectedOrders[order.id]} 
                            onCheckedChange={() => toggleSelection(order.id)}
                        />
                        
                        <Avatar className="h-9 w-9">
                            <AvatarImage src={`https://avatar.vercel.sh/${order.client_id}.png`} alt="Avatar" />
                            <AvatarFallback>{order.client_name_cache.charAt(0)}</AvatarFallback>
                        </Avatar>
                        
                        <div className="flex-1 space-y-1">
                            <p className="text-sm font-medium leading-none">
                                {order.client_name_cache}
                            </p>
                            <p className="text-xs text-muted-foreground">
                                Pedido #{order.id.slice(-6)}
                            </p>
                        </div>

                        <div className="flex items-center gap-2">
                            <p className="text-xs text-muted-foreground">Bultos:</p>
                            <Input 
                                type="number" 
                                min="1" 
                                className="h-8 w-16" 
                                value={orderBundles[order.id] || 1}
                                onChange={(e) => updateBundleCount(order.id, parseInt(e.target.value))}
                            />
                        </div>

                        <div className="font-medium text-right flex items-center gap-4">
                            <div className="hidden sm:block">
                               <p className="text-sm">{formatCurrency(order.total_amount)}</p>
                               <Badge variant="outline" className="text-[10px] py-0">Armado</Badge>
                           </div>
                           {order.notes && (
                                <Button variant="ghost" size="icon" className="h-8 w-8" onClick={() => setActiveNote({ note: order.notes!, clientName: order.client_name_cache })}>
                                    <StickyNote className="h-4 w-4" />
                                </Button>
                            )}
                        </div>

                        <Button 
                            variant="secondary" 
                            size="sm" 
                            className="h-8 shrink-0"
                            onClick={() => handleUpdateStatus(order.id, 'transito')}
                            disabled={isPending}
                        >
                            Despachar
                        </Button>
                    </div>
                ))}
            </div>

            {/* Floating Notes */}
            <div className="fixed bottom-4 right-4 space-y-2 z-50">
                {activeNote && (
                    <OrderNoteWidget
                        clientName={activeNote.clientName}
                        note={activeNote.note}
                        onClose={() => setActiveNote(null)}
                        onMinimize={() => {
                            setMinimizedNotes([...minimizedNotes, activeNote]);
                            setActiveNote(null);
                        }}
                        isMinimized={false}
                    />
                )}
            </div>
        </div>
    );
}
