"use client";

import { useState, useEffect, useCallback } from "react";
import { Search, X } from "lucide-react";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";

const DEBOUNCE_DELAY = 300;

interface SearchInputProps {
  placeholder?: string;
  onSearch: (value: string) => void;
  initialValue?: string;
  className?: string;
}

export function SearchInput({
  placeholder = "Buscar...",
  onSearch,
  initialValue = "",
  className,
}: SearchInputProps) {
  const [value, setValue] = useState(initialValue);

  useEffect(() => {
    setValue(initialValue);
  }, [initialValue]);

  useEffect(() => {
    const timer = setTimeout(() => {
      if (value !== initialValue) {
        onSearch(value);
      }
    }, DEBOUNCE_DELAY);

    return () => clearTimeout(timer);
  }, [value, onSearch, initialValue]);

  const handleClear = useCallback(() => {
    setValue("");
    onSearch("");
  }, [onSearch]);

  return (
    <div className={`relative flex items-center gap-2 ${className}`}>
      <Search className="absolute left-3 h-4 w-4 text-muted-foreground" />
      <Input
        type="text"
        placeholder={placeholder}
        value={value}
        onChange={(e) => setValue(e.target.value)}
        className="pl-9 pr-9"
      />
      {value && (
        <Button
          variant="ghost"
          size="sm"
          className="absolute right-1 h-7 w-7 p-0"
          onClick={handleClear}
        >
          <X className="h-4 w-4" />
          <span className="sr-only">Limpiar búsqueda</span>
        </Button>
      )}
    </div>
  );
}
