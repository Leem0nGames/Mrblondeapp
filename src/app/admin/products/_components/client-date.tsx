
"use client";

import { useState, useEffect } from "react";

export function ClientDate({ date }: { date: string }) {
  const [isClient, setIsClient] = useState(false);

  useEffect(() => {
    setIsClient(true);
  }, []);

  return isClient ? <>{new Date(date).toLocaleDateString()}</> : null;
}
