"use client";

// Editing sheet: the same SubscriptionForm bound to an existing subscription.

import { useMemo } from "react";
import { useKiper } from "@/lib/store";
import { useUI } from "@/lib/ui";
import { SubscriptionForm } from "./SubscriptionForm";
import { Sheet } from "./ui";

export function EditSheet() {
  const editId = useUI((s) => s.editSubId);
  const close = useUI((s) => s.closeEdit);
  const subs = useKiper((s) => s.subscriptions);
  const sub = useMemo(() => subs.find((x) => x.id === editId) ?? null, [subs, editId]);

  return (
    <Sheet open={editId != null} onClose={close} title="Редактирование" detent="full">
      {sub && <SubscriptionForm editing={sub} onDone={close} />}
    </Sheet>
  );
}
