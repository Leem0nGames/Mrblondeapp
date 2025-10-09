
"use client";

import Link from "next/link";
import type { Client } from "@/types";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";

export function PendingClients({ clients }: { clients: Client[] }) {

     if (clients.length === 0) {
        return (
            <div className="text-center text-muted-foreground py-8">
                <p>No hay clientes pendientes.</p>
            </div>
        )
    }

    return (
        <div className="space-y-4">
            {clients.map((client) => (
                <div key={client.id} className="flex items-center">
                    <Avatar className="h-9 w-9">
                        <AvatarImage src={`https://avatar.vercel.sh/${client.id}.png`} alt="Avatar" />
                        <AvatarFallback>{client.contact_name?.charAt(0) ?? 'C'}</AvatarFallback>
                    </Avatar>
                    <div className="ml-4 space-y-1">
                        <p className="text-sm font-medium leading-none">
                            {client.contact_name}
                        </p>
                        <p className="text-sm text-muted-foreground">
                            {client.email}
                        </p>
                    </div>
                    <Button asChild variant="outline" size="sm" className="ml-auto">
                        <Link href="/admin/clients">
                           Asignar Convenio
                        </Link>
                    </Button>
                </div>
            ))}
        </div>
    );
}
