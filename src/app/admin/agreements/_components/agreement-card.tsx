"use client";

import { useTransition } from "react";
import { MoreHorizontal, Trash2, Edit, Tag, Percent, FileText } from "lucide-react";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { useToast } from "@/hooks/use-toast";
import type { Agreement } from "@/types";
import { deleteAgreement } from "@/app/actions/admin.actions";
import { AgreementDialog } from "./agreement-dialog";

export function AgreementCard({ agreement }: { agreement: Agreement }) {
  const [isPending, startTransition] = useTransition();
  const { toast } = useToast();

  const handleDelete = () => {
    startTransition(async () => {
      const result = await deleteAgreement(agreement.id);
      if (result.error) {
        toast({
          title: "Error",
          description: result.error.message,
          variant: "destructive",
        });
      } else {
        toast({
          title: "Éxito",
          description: "Convenio eliminado correctamente.",
        });
      }
    });
  };

  return (
    <Card className="flex flex-col">
      <CardHeader>
        <div className="flex items-start justify-between">
          <div className="space-y-1">
            <CardTitle>{agreement.name}</CardTitle>
            <CardDescription className="capitalize">{agreement.client_type}</CardDescription>
          </div>
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="icon" className="h-8 w-8">
                <MoreHorizontal className="h-4 w-4" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuLabel>Acciones</DropdownMenuLabel>
              <AgreementDialog agreement={agreement}>
                <DropdownMenuItem onSelect={(e) => e.preventDefault()}>
                  <Edit className="mr-2 h-4 w-4" />
                  Editar
                </DropdownMenuItem>
              </AgreementDialog>
              <DropdownMenuSeparator />
              <AlertDialog>
                <AlertDialogTrigger asChild>
                  <DropdownMenuItem
                    className="text-destructive"
                    onSelect={(e) => e.preventDefault()}
                  >
                    <Trash2 className="mr-2 h-4 w-4" />
                    Eliminar
                  </DropdownMenuItem>
                </AlertDialogTrigger>
                <AlertDialogContent>
                  <AlertDialogHeader>
                    <AlertDialogTitle>¿Estás seguro?</AlertDialogTitle>
                    <AlertDialogDescription>
                      Esta acción no se puede deshacer. Esto eliminará permanentemente el convenio y sus configuraciones.
                    </AlertDialogDescription>
                  </AlertDialogHeader>
                  <AlertDialogFooter>
                    <AlertDialogCancel>Cancelar</AlertDialogCancel>
                    <AlertDialogAction
                      onClick={handleDelete}
                      disabled={isPending}
                      className="bg-destructive hover:bg-destructive/90"
                    >
                      {isPending ? "Eliminando..." : "Eliminar"}
                    </AlertDialogAction>
                  </AlertDialogFooter>
                </AlertDialogContent>
              </AlertDialog>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </CardHeader>
      <CardContent className="flex-grow space-y-4">
        <div>
          <h4 className="text-sm font-medium mb-2 flex items-center gap-2">
            <Tag className="h-4 w-4" />
            Productos Asignados ({agreement.agreement_products.length})
          </h4>
          <div className="space-y-1 text-sm text-muted-foreground">
            {agreement.agreement_products.length > 0 ? (
              agreement.agreement_products.slice(0, 3).map(item => (
                <div key={item.products.id} className="flex justify-between">
                  <span>{item.products.name}</span>
                  <span className="font-mono">${item.price.toLocaleString()}</span>
                </div>
              ))
            ) : <p>Ninguno</p>}
            {agreement.agreement_products.length > 3 && <p>y {agreement.agreement_products.length - 3} más...</p>}
          </div>
        </div>
        <div>
          <h4 className="text-sm font-medium mb-2 flex items-center gap-2">
            <Percent className="h-4 w-4" />
            Promociones Activas ({agreement.agreement_promotions.length})
          </h4>
          <div className="flex flex-wrap gap-2">
             {agreement.agreement_promotions.length > 0 ? (
              agreement.agreement_promotions.map(item => (
                <Badge key={item.promotions.id} variant="secondary">{item.promotions.name}</Badge>
              ))
             ) : <p className="text-sm text-muted-foreground">Ninguna</p>}
          </div>
        </div>
      </CardContent>
      <CardFooter className="border-t pt-4">
        <Button variant="outline" className="w-full">
            <FileText className="mr-2 h-4 w-4" />
            Gestionar Convenio
        </Button>
      </CardFooter>
    </Card>
  );
}
