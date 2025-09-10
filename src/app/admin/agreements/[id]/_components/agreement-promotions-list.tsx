"use client"

import type { AgreementPromotion } from "@/types";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { X } from "lucide-react";


export default function AgreementPromotionsList({ promotions }: { promotions: AgreementPromotion[] }) {

  if (promotions.length === 0) {
    return (
        <div className="text-center py-12 text-muted-foreground">
            <p>No hay promociones asignadas a este convenio.</p>
            <p className="text-sm">Usa el botón "Asignar Promoción" para empezar.</p>
        </div>
    )
  }

  return (
    <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        {promotions.map(item => (
            <Card key={item.promotions.id}>
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                    <CardTitle className="text-sm font-medium">{item.promotions.name}</CardTitle>
                    <Button variant="ghost" size="icon" className="h-6 w-6 text-muted-foreground hover:text-destructive">
                        <X className="h-4 w-4" />
                        <span className="sr-only">Desasignar</span>
                    </Button>
                </CardHeader>
                <CardContent>
                    <p className="text-xs text-muted-foreground">
                        {item.promotions.description}
                    </p>
                    <pre className="mt-2 text-xs bg-muted/50 p-2 rounded-md font-code overflow-x-auto">
                        <code>{JSON.stringify(item.promotions.rules, null, 2)}</code>
                    </pre>
                </CardContent>
            </Card>
        ))}
    </div>
  );
}
