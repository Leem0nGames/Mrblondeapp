
"use client";

import { MoreHorizontal, Trash2 } from "lucide-react";
import { useTransition } from "react";
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
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardFooter,
} from "@/components/ui/card";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuTrigger,
  DropdownMenuSeparator
} from "@/components/ui/dropdown-menu";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Promotion } from "@/types";
import { deletePromotion } from "@/app/actions/admin.actions";
import { useToast } from "@/hooks/use-toast";
import { formatDate } from "@/lib/utils";
import { EntityDialog } from "../../_components/entity-dialog";
import { promotionFormConfig } from "./form-config";

const formatRule = (rules: any): string => {
  if (!rules || typeof rules !== 'object') {
    return 'Regla no definida';
  }

  switch (rules.type) {
    case 'buy_x_get_y_free':
      return `Llevando ${rules.buy || 'X'} unidades, obtienes ${rules.get || 'Y'} de regalo.`;
    case 'free_shipping':
      return `Envío gratis con ${rules.min_units || 'X'} unidades o más.`;
    default:
      return 'Regla personalizada.';
  }
};

interface PromotionsTableProps {
    promotions: Promotion[];
    emptyState: React.ReactNode;
}

export default function PromotionsTable({ promotions, emptyState }: PromotionsTableProps) {
  const [isPending, startTransition] = useTransition();
  const { toast } = useToast();

  const handleDelete = (promotionId: string) => {
    startTransition(async () => {
      const result = await deletePromotion(promotionId);
      if (result.error) {
        toast({
          title: "Error",
          description: result.error.message,
          variant: "destructive",
        });
      } else {
        toast({
          title: "Éxito",
          description: "Promoción eliminada correctamente.",
        });
      }
    });
  };

  if (promotions.length === 0) {
    return <>{emptyState}</>;
  }
  
  return (
    <Card>
      <CardContent className="p-0">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Nombre</TableHead>
              <TableHead>Descripción</TableHead>
              <TableHead className="hidden md:table-cell">Regla</TableHead>
              <TableHead className="hidden md:table-cell">Creada</TableHead>
              <TableHead>
                <span className="sr-only">Actions</span>
              </TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {promotions.map((promotion) => (
              <TableRow key={promotion.id}>
                <TableCell className="font-medium">{promotion.name}</TableCell>
                <TableCell>
                  {promotion.description}
                </TableCell>
                 <TableCell className="hidden md:table-cell text-sm text-muted-foreground">
                    {formatRule(promotion.rules)}
                </TableCell>
                <TableCell className="hidden md:table-cell">
                  {formatDate(promotion.created_at)}
                </TableCell>
                <TableCell className="text-right">
                  <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                      <Button aria-haspopup="true" size="icon" variant="ghost">
                        <MoreHorizontal className="h-4 w-4" />
                        <span className="sr-only">Toggle menu</span>
                      </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end">
                      <DropdownMenuLabel>Acciones</DropdownMenuLabel>
                      <EntityDialog formConfig={promotionFormConfig} entity={promotion}>
                        <DropdownMenuItem onSelect={(e) => e.preventDefault()}>
                          Editar
                        </DropdownMenuItem>
                      </EntityDialog>
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
                            <AlertDialogTitle>
                              ¿Estás seguro?
                            </AlertDialogTitle>
                            <AlertDialogDescription>
                              Esta acción no se puede deshacer. Esto eliminará permanentemente la promoción.
                            </AlertDialogDescription>
                          </AlertDialogHeader>
                          <AlertDialogFooter>
                            <AlertDialogCancel>Cancelar</AlertDialogCancel>
                            <AlertDialogAction
                              onClick={() => handleDelete(promotion.id)}
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
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </CardContent>
      <CardFooter>
        <div className="text-xs text-muted-foreground">
          Mostrando <strong>{promotions.length}</strong> de{" "}
          <strong>{promotions.length}</strong> promociones
        </div>
      </CardFooter>
    </Card>
  );
}
