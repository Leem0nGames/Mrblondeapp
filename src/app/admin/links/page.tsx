
"use client";

import { useState, useTransition, useEffect } from "react";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { generateOrderLink, getAgreements, getClients } from "@/app/actions/admin.actions";
import { useToast } from "@/hooks/use-toast";
import { Copy } from "lucide-react";
import type { Agreement, Client } from "@/types";
import { Skeleton } from "@/components/ui/skeleton";
import { Input } from "@/components/ui/input";

export default function GenerateLinkPage() {
  const [agreements, setAgreements] = useState<Agreement[]>([]);
  const [clients, setClients] = useState<Client[]>([]);
  const [selectedAgreementId, setSelectedAgreementId] = useState<string>("");
  const [selectedClientId, setSelectedClientId] = useState<string>("");
  const [generatedLink, setGeneratedLink] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();
  const [isLoading, startLoading] = useTransition();
  const { toast } = useToast();

  useEffect(() => {
    startLoading(async () => {
      const agreementsPromise = getAgreements();
      const clientsPromise = getClients();

      const [agreementsResult, clientsResult] = await Promise.all([agreementsPromise, clientsPromise]);

      if (agreementsResult.error) {
        toast({
          title: "Error",
          description: "No se pudieron cargar los convenios.",
          variant: "destructive",
        });
      } else {
        setAgreements(agreementsResult.data ?? []);
      }

      if (clientsResult.error) {
        toast({
          title: "Error",
          description: "No se pudieron cargar los clientes.",
          variant: "destructive",
        });
      } else {
        setClients(clientsResult.data ?? []);
      }
    });
  }, [toast]);

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const selectedClient = clients.find(c => c.id === selectedClientId);

    if (!selectedClient) {
      toast({
        title: "Error",
        description: "Por favor, selecciona un cliente.",
        variant: "destructive",
      });
      return;
    }
     if (!selectedAgreementId) {
      toast({
        title: "Error",
        description: "Por favor, selecciona un convenio.",
        variant: "destructive",
      });
      return;
    }
    startTransition(async () => {
      const result = await generateOrderLink(selectedAgreementId, selectedClient.name);
      if (result.error) {
        toast({
          title: "Error al generar enlace",
          description: result.error.message,
          variant: "destructive",
        });
        setGeneratedLink(null);
      } else {
        setGeneratedLink(result.link);
        toast({
          title: "Enlace generado correctamente!",
        });
      }
    });
  };

  const copyToClipboard = () => {
    if (generatedLink) {
      navigator.clipboard.writeText(generatedLink);
      toast({ title: "Enlace copiado al portapapeles!" });
    }
  };

  return (
    <div className="grid flex-1 items-start gap-4 md:gap-8">
      <h1 className="text-2xl font-bold">Generar Enlace de Pedido</h1>
      <Card className="w-full max-w-lg mx-auto">
        <CardHeader>
          <CardTitle>Generar Enlace de Pedido</CardTitle>
          <CardDescription>
            Crea un enlace único para que un cliente haga un pedido basado en un convenio.
          </CardDescription>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="space-y-4">
                <Skeleton className="h-4 w-1/4" />
                <Skeleton className="h-10 w-full" />
                <Skeleton className="h-4 w-1/4" />
                <Skeleton className="h-10 w-full" />
                <Skeleton className="h-10 w-full mt-4" />
            </div>
          ) : (
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="client">Cliente</Label>
               <Select
                value={selectedClientId}
                onValueChange={setSelectedClientId}
              >
                <SelectTrigger id="client">
                  <SelectValue placeholder="Selecciona un cliente" />
                </SelectTrigger>
                <SelectContent>
                  {clients.map((client) => (
                      <SelectItem key={client.id} value={client.id}>{client.name}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label htmlFor="agreement">Convenio</Label>
              <Select
                value={selectedAgreementId}
                onValueChange={setSelectedAgreementId}
              >
                <SelectTrigger id="agreement">
                  <SelectValue placeholder="Selecciona un convenio" />
                </SelectTrigger>
                <SelectContent>
                  {agreements.map((agreement) => (
                      <SelectItem key={agreement.id} value={agreement.id}>{agreement.agreement_name}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <Button type="submit" className="w-full" disabled={isPending || isLoading}>
              {isPending ? "Generando..." : "Generar Enlace"}
            </Button>
          </form>
          )}

          {generatedLink && (
            <div className="mt-6 space-y-2">
              <Label>Enlace Generado</Label>
              <div className="flex items-center gap-2">
                <Input
                  type="text"
                  readOnly
                  value={generatedLink}
                  className="bg-muted"
                />
                <Button
                  variant="outline"
                  size="icon"
                  onClick={copyToClipboard}
                >
                  <Copy className="h-4 w-4" />
                </Button>
              </div>
              <p className="text-xs text-muted-foreground">
                Este enlace expirará en 24 horas.
              </p>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
