
"use client";

import { useTransition, useState } from "react";
import type { Order } from "@/types";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import { Check, StickyNote } from "lucide-react";
import { completeOrder } from "@/app/admin/actions/dashboard.actions";
import { useToast } from "@/hooks/use-toast";
import { Badge } from "@/components/ui/badge";
import { OrderNoteWidget } from "./order-note-widget";

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
    const [activeNote, setActiveNote] = useState<NoteInfo | null>(null);
    const [minimizedNotes, setMinimizedNotes] = useState<NoteInfo[]>([]);


    const handleCompleteOrder = (orderId: string, orderTotal: number) => {
        const originalOrders = orders;
        setOrders(currentOrders => currentOrders.filter(order => order.id !== orderId));

        startTransition(async () => {
            const result = await completeOrder(orderId, orderTotal);
            if (result.error) {
                toast({
                    title: "Error",
                    description: "No se pudo completar el pedido. Se ha restaurado.",
                    variant: "destructive"
                });
                setOrders(originalOrders);
            } else {
                toast({
                    title: "¡Pedido Completado!",
                    description: "El pedido se ha marcado como completado y las estadísticas se han actualizado."
                });
            }
        });
    }

    const showNote = (note: string, clientName: string) => {
        const noteInfo = { note, clientName };
        if (minimizedNotes.some(n => n.note === note && n.clientName === clientName)) {
            setMinimizedNotes(minimizedNotes.filter(n => !(n.note === note && n.clientName === clientName)));
        }
        setActiveNote(noteInfo);
    };

    const closeNote = () => {
        setActiveNote(null);
    };

    const minimizeNote = () => {
        if (activeNote && !minimizedNotes.some(n => n.note === activeNote.note && n.clientName === activeNote.clientName)) {
            setMinimizedNotes([...minimizedNotes, activeNote]);
        }
        setActiveNote(null);
    };


    if (orders.length === 0) {
        return (
            <div className="text-center text-muted-foreground py-8">
                <p>No hay pedidos pendientes.</p>
            </div>
        )
    }

    return (
        <div className="relative">
            <div className="space-y-8">
                {orders.map((order) => (
                    <div key={order.id} className="flex items-center transition-opacity">
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
                        <div className="ml-auto font-medium text-right flex items-center gap-4">
                            <div>
                               <p>{formatCurrency(order.total_amount)}</p>
                               <Badge variant="outline" className="mt-1">Pendiente</Badge>
                           </div>
                           {order.notes && (
                                <Button variant="ghost" size="icon" className="h-8 w-8 text-muted-foreground hover:text-primary" onClick={() => showNote(order.notes!, order.client_name_cache)}>
                                    <StickyNote className="h-5 w-5" />
                                </Button>
                            )}
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

            {/* Floating Widgets Area */}
            <div className="fixed bottom-4 right-4 space-y-2 z-50">
                {activeNote && (
                    <OrderNoteWidget
                        clientName={activeNote.clientName}
                        note={activeNote.note}
                        onClose={closeNote}
                        onMinimize={minimizeNote}
                        isMinimized={false}
                    />
                )}
                 {minimizedNotes.map((noteInfo, index) => (
                    <OrderNoteWidget
                        key={index}
                        clientName={noteInfo.clientName}
                        note={noteInfo.note}
                        onClose={() => setMinimizedNotes(minimizedNotes.filter(n => !(n.note === noteInfo.note && n.clientName === noteInfo.clientName)))}
                        onMaximize={() => showNote(noteInfo.note, noteInfo.clientName)}
                        isMinimized={true}
                    />
                ))}
            </div>
        </div>
    );
}

    
