
"use client";

import { useState } from "react";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";
import { Button } from "@/components/ui/button";
import { Bell, Check } from "lucide-react";
import { Card, CardHeader, CardTitle, CardDescription, CardFooter } from "@/components/ui/card";
import { ScrollArea } from "@/components/ui/scroll-area";

const notifications = [
    { 
        title: "Nuevo Pedido #4567",
        description: "Cliente: Barbería 'El Don'",
        time: "hace 5 min",
    },
    {
        title: "Cliente Pendiente de Convenio",
        description: "Distribuidora 'Cosmos' ha completado el alta.",
        time: "hace 1 hora",
    },
    {
        title: "Stock Bajo",
        description: "Cera Modeladora 'Rock Hard': 5 unidades restantes.",
        time: "ayer",
    },
    {
        title: "Nuevo Pedido #4566",
        description: "Cliente: 'The Style Room'",
        time: "ayer",
    }
];

export function Notifications() {
  const [hasUnread, setHasUnread] = useState(true);

  const handleMarkAsRead = () => {
    setHasUnread(false);
  };

  return (
    <Popover>
      <PopoverTrigger asChild>
        <Button variant="outline" size="icon" className="relative shrink-0">
          <Bell className="h-5 w-5" />
          {hasUnread && (
            <span className="absolute top-0 right-0 block h-2 w-2 rounded-full bg-destructive ring-2 ring-background" />
          )}
          <span className="sr-only">Abrir notificaciones</span>
        </Button>
      </PopoverTrigger>
      <PopoverContent className="w-80 p-0" align="end">
        <Card className="border-0 shadow-none">
          <CardHeader className="flex flex-row items-center justify-between">
            <CardTitle className="text-lg">Notificaciones</CardTitle>
            {hasUnread && (
              <Button
                variant="ghost"
                size="sm"
                onClick={handleMarkAsRead}
                className="h-auto p-1 text-xs"
              >
                <Check className="mr-1 h-3 w-3" />
                Marcar como leídas
              </Button>
            )}
          </CardHeader>
          <ScrollArea className="h-96">
            <div className="flex flex-col gap-4 p-4 pt-0">
                {notifications.map((notification, index) => (
                    <div key={index} className="flex items-start gap-3">
                        <div className="mt-1 flex h-2 w-2 translate-y-1.5 shrink-0 rounded-full bg-primary" />
                        <div className="grid gap-0.5">
                            <p className="font-semibold text-sm">{notification.title}</p>
                            <p className="text-xs text-muted-foreground">{notification.description}</p>
                            <p className="text-xs text-muted-foreground/70">{notification.time}</p>
                        </div>
                    </div>
                ))}
            </div>
          </ScrollArea>
           <CardFooter>
             <p className="text-xs text-muted-foreground/80 text-center w-full">
                Próximamente: Notificaciones en tiempo real.
            </p>
          </CardFooter>
        </Card>
      </PopoverContent>
    </Popover>
  );
}
