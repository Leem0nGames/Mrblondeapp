"use client";

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { cn } from "@/lib/utils";
import type { ClientHeatmapData } from "@/types";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";
import { TrendingUp, TrendingDown, HelpCircle } from "lucide-react";
import Link from "next/link";

const formatCurrency = (value: number) => {
    return new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', maximumFractionDigits: 0 }).format(value);
}

// Simple treemap layout algorithm
const generateTreemap = (clients: ClientHeatmapData[]) => {
    if (clients.length === 0) return [];
    
    clients.sort((a, b) => b.value - a.value);

    if (clients.length === 1) {
        return [{ ...clients[0], x: 0, y: 0, width: 100, height: 100 }];
    }
    if (clients.length === 2) {
        return [
            { ...clients[0], x: 0, y: 0, width: 65, height: 100 },
            { ...clients[1], x: 65, y: 0, width: 35, height: 100 },
        ];
    }
    if (clients.length >= 3) {
        const main = { ...clients[0], x: 0, y: 0, width: 65, height: 100 };
        const second = { ...clients[1], x: 65, y: 0, width: 35, height: 50 };
        const third = { ...clients[2], x: 65, y: 50, width: 35, height: 50 };
        
        const remaining = clients.slice(3).map((client, index) => {
            // This is a simplified layout for smaller items, not a true treemap algorithm
            const x = 65 + (index % 2) * 17.5;
            const y = 50 + Math.floor(index / 2) * 25;
            return { ...client, x, y, width: 17.5, height: 25 };
        }).slice(0, 4); // Limit to 4 small items for simplicity
        
         if (clients.length >= 5) {
             main.height = 50;
             const fourth = { ...clients[3], x: 0, y: 50, width: 32.5, height: 50 };
             const fifth = { ...clients[4], x: 32.5, y: 50, width: 32.5, height: 50 };
             return [main, second, third, fourth, fifth];
         }
        
         if (clients.length >= 4) {
             main.height = 50;
             const fourth = { ...clients[3], x: 0, y: 50, width: 65, height: 50 };
             return [main, second, third, fourth];
         }

        return [main, second, third];
    }
    return [];
};


const HeatmapBlock = ({ client }: { client: ReturnType<typeof generateTreemap>[0] }) => {
    const isHighValue = client.value > 0;
    const hasRisk = client.risk > 0;

    const colorClass = hasRisk 
        ? "bg-destructive/80 text-destructive-foreground" 
        : isHighValue 
        ? "bg-green-600/90 text-primary-foreground" 
        : "bg-muted text-muted-foreground";

    const tooltipText = hasRisk ? `Cliente con pedidos vencidos. Valor total: ${formatCurrency(client.value)}` : `Cliente valioso. Valor total: ${formatCurrency(client.value)}`;

    return (
         <Tooltip>
            <TooltipTrigger asChild>
                <Link href={`/admin/clients/${client.id}`}
                    style={{
                        left: `${client.x}%`,
                        top: `${client.y}%`,
                        width: `${client.width}%`,
                        height: `${client.height}%`,
                    }}
                    className={cn(
                        "absolute m-0.5 p-2 flex flex-col justify-between rounded-lg transition-all duration-300 ease-in-out hover:scale-[1.02] hover:z-10",
                        colorClass
                    )}
                >
                    <div className="flex justify-between items-start">
                        <h4 className="font-bold text-sm sm:text-base break-words">{client.name}</h4>
                        {hasRisk && <TrendingDown className="h-4 w-4 flex-shrink-0" />}
                        {!hasRisk && isHighValue && <TrendingUp className="h-4 w-4 flex-shrink-0" />}
                    </div>
                    <div>
                        <p className="font-semibold text-lg sm:text-xl">{formatCurrency(client.value)}</p>
                        <p className="text-xs opacity-80">Total Comprado</p>
                    </div>
                </Link>
            </TooltipTrigger>
            <TooltipContent>
                <p>{tooltipText}</p>
            </TooltipContent>
        </Tooltip>
    )
}

export function ClientsHeatmap({ clients }: { clients: ClientHeatmapData[] }) {
    const topClients = clients.sort((a, b) => b.value - a.value).slice(0, 7);
    const layout = generateTreemap(topClients);

     if (clients.length === 0) {
        return (
             <Card>
                <CardHeader>
                    <CardTitle>Heatmap de Clientes</CardTitle>
                    <CardDescription>Una visualización del valor y riesgo de tus clientes.</CardDescription>
                </CardHeader>
                <CardContent className="h-72 flex items-center justify-center text-muted-foreground border-2 border-dashed rounded-lg">
                    <p>No hay datos de clientes para generar el heatmap.</p>
                </CardContent>
            </Card>
        )
    }

    return (
        <Card>
            <CardHeader>
                <div className="flex items-center gap-2">
                    <CardTitle>Heatmap de Clientes</CardTitle>
                    <TooltipProvider>
                        <Tooltip>
                            <TooltipTrigger>
                                <HelpCircle className="h-4 w-4 text-muted-foreground" />
                            </TooltipTrigger>
                            <TooltipContent>
                                <p>El tamaño representa el valor de compra total. El color indica el riesgo (rojo = pedidos vencidos).</p>
                            </TooltipContent>
                        </Tooltip>
                    </TooltipProvider>
                </div>
                <CardDescription>
                    Un vistazo rápido al valor y riesgo de tus principales clientes.
                </CardDescription>
            </CardHeader>
            <CardContent>
                 <TooltipProvider>
                    <div className="w-full h-80 sm:h-96 relative">
                        {layout.map((client) => (
                           <HeatmapBlock key={client.id} client={client} />
                        ))}
                    </div>
                 </TooltipProvider>
            </CardContent>
        </Card>
    );
}
