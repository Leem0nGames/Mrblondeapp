
import PromotionsTable from './_components/promotions-table';

export default function PromotionsPage() {
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-900">Promotions</h1>
        <button className="btn-primary">New Promotion</button>
      </div>
      <PromotionsTable
        promotions={[
          {
            id: 'promo-1',
            name: 'Promoción de Navidad',
            description: 'Descuento del 20% en productos seleccionados',
            rules: { type: 'min_amount_discount', percentage: 20, min_amount: 1000 },
            created_at: new Date().toISOString()
          },
          {
            id: 'promo-2',
            name: 'Promoción de Verano',
            description: '2x1 en productos de temporada',
            rules: { type: 'buy_x_get_y_free', buy: 2, get: 1 },
            created_at: new Date().toISOString()
          }
        ]}
        emptyState={
          <div className="text-center py-12">
            <p className="text-muted-foreground">No promotions found</p>
          </div>
        }
      />
    </div>
  );
}
