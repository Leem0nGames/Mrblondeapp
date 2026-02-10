
import { PriceListsTable } from './_components/pricelists-table';

export default function PricelistsPage() {
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-900">Pricelists</h1>
        <button className="btn-primary">New Pricelist</button>
      </div>
      <PriceListsTable
        priceLists={[
          {
            id: 'list-1',
            name: 'Lista de Precios General',
            created_at: new Date().toISOString(),
            prices_include_vat: true
          },
          {
            id: 'list-2',
            name: 'Lista de Precios Mayorista',
            created_at: new Date().toISOString(),
            prices_include_vat: true
          }
        ]}
        emptyState={
          <div className="text-center py-12">
            <p className="text-muted-foreground">No pricelists found</p>
          </div>
        }
      />
    </div>
  );
}
