
"use client";

import { useState, useEffect, useCallback } from "react";
import type { PriceList } from "@/types";
import { getPriceLists } from "@/app/admin/agreements/actions/admin.actions";
import { useFormContext } from "react-hook-form";

// This is a new wrapper component to contain the client-side logic
// of fetching data for the agreement form.

export function AgreementFormFieldsWrapper({ renderFields }: { renderFields: (form: any, props: any) => React.ReactNode }) {
  const [priceLists, setPriceLists] = useState<PriceList[]>([]);
  const form = useFormContext();

  const fetchPriceLists = useCallback(async () => {
    const { data } = await getPriceLists();
    setPriceLists(data ?? []);
  }, []);

  useEffect(() => {
    fetchPriceLists();
  }, [fetchPriceLists]);
  
  const handlePriceListCreated = useCallback((newPriceList: PriceList) => {
    setPriceLists(current => [...current, newPriceList]);
    form.setValue('price_list_id', newPriceList.id, { shouldValidate: true });
  }, [form]);

  // We pass the fetched data and the callback down to the actual render function
  return renderFields(form, { priceLists, onPriceListCreated: handlePriceListCreated });
}
