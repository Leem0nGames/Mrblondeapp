
"use client";

import Link from 'next/link';
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { CheckCircle, AlertCircle, ArrowRight, Users, ClipboardList, Percent, Landmark } from 'lucide-react';
import type { DashboardStats } from "@/types";
import { cn } from '@/lib/utils';

type ChecklistItemProps = {
    title: string;
    description: string;
    isComplete: boolean;
    href: string;
    icon: React.ElementType;
}

function ChecklistItem({ title, description, isComplete, href, icon: Icon }: ChecklistItemProps) {
    return (
        <div className="flex items-start gap-4 p-4 rounded-lg bg-background hover:bg-muted/50 transition-colors">
            <div className={cn(
                "flex-shrink-0 w-8 h-8 rounded-full flex items-center justify-center",
                isComplete ? "bg-green-500/20 text-green-500" : "bg-amber-500/20 text-amber-500"
            )}>
                {isComplete ? <CheckCircle className="w-5 h-5" /> : <Icon className="w-5 h-5" />}
            </div>
            <div className="flex-grow">
                <p className="font-semibold">{title}</p>
                <p className="text-sm text-muted-foreground">{description}</p>
            </div>
            {!isComplete && (
                <Button asChild variant="ghost" size="sm" className="ml-auto">
                    <Link href={href}>
                        Ir a Crear <ArrowRight className="w-4 h-4 ml-2" />
                    </Link>
                </Button>
            )}
        </div>
    )
}

export function SetupChecklist({ stats }: { stats: DashboardStats }) {

    const checklistItems = [
        {
            title: "Crea tu primer Cliente",
            description: "Los clientes son las barberías o distribuidoras que te comprarán.",
            isComplete: stats.total_clients > 0,
            href: "/admin/clients",
            icon: Users,
        },
        {
            title: "Crea una Lista de Precios",
            description: "Las listas definen qué productos se venden y a qué precio.",
            isComplete: stats.total_pricelists > 0,
            href: "/admin/commercial-settings?tab=pricelists",
            icon: ClipboardList,
        },
        {
            title: "Crea una Promoción",
            description: "Define ofertas como '8+2' o envíos gratis para tus convenios.",
            isComplete: stats.total_promotions > 0,
            href: "/admin/commercial-settings?tab=promotions",
            icon: Percent,
        },
        {
            title: "Crea una Condición de Venta",
            description: "Establece plazos de pago o formas de financiación.",
            isComplete: stats.total_sales_conditions > 0,
            href: "/admin/commercial-settings?tab=sales-conditions",
            icon: Landmark,
        },
    ];

    const completedCount = checklistItems.filter(item => item.isComplete).length;
    const totalCount = checklistItems.length;

    return (
        <Card>
            <CardHeader>
                <div className="flex items-center gap-2">
                    <AlertCircle className="w-6 h-6 text-primary" />
                    <CardTitle>¡Bienvenido! Completa la configuración inicial</CardTitle>
                </div>
                <CardDescription>
                    Sigue estos pasos para dejar tu sistema listo para operar. Completado: {completedCount} de {totalCount}.
                </CardDescription>
            </CardHeader>
            <CardContent>
                <div className="space-y-2">
                    {checklistItems.map(item => <ChecklistItem key={item.title} {...item} />)}
                </div>
            </CardContent>
        </Card>
    );
}
