
import SalesConditionsTable from './_components/sales-conditions-table';

export default function SalesConditionsPage() {
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-900">Sales Conditions</h1>
        <button className="btn-primary">New Sales Condition</button>
      </div>
      <SalesConditionsTable
        salesConditions={[
          {
            id: 'cond-1',
            name: 'Condición de Pago 30 días',
            description: 'Pago a 30 días netos',
            rules: { type: 'net_days', days: 30 },
            created_at: new Date().toISOString()
          },
          {
            id: 'cond-2',
            name: 'Condición de Contado',
            description: 'Pago al contado con descuento',
            rules: { type: 'discount', percentage: 5 },
            created_at: new Date().toISOString()
          }
        ]}
        emptyState={
          <div className="text-center py-12">
            <p className="text-muted-foreground">No sales conditions found</p>
          </div>
        }
      />
    </div>
  );
}
