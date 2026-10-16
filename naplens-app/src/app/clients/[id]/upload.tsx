"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { createClient } from "@/lib/supabase/client";

// Uploads go straight from the browser to Storage: server actions cap bodies at 1MB.
export function FileUpload({ clientId }: { clientId: string }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string>();

  async function onChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setBusy(true);
    setError(undefined);

    const supabase = createClient();
    const path = `${clientId}/${crypto.randomUUID()}-${file.name.replace(/[^\w.-]/g, "_")}`;
    const { error: uploadError } = await supabase.storage
      .from("client-files")
      .upload(path, file);
    if (uploadError) {
      setError(uploadError.message);
    } else {
      const { error: rowError } = await supabase.from("client_files").insert({
        client_id: clientId,
        name: file.name,
        path,
        size_bytes: file.size,
      });
      if (rowError) {
        await supabase.storage.from("client-files").remove([path]);
        setError(rowError.message);
      } else {
        router.refresh();
      }
    }
    setBusy(false);
    e.target.value = "";
  }

  return (
    <div className="flex flex-col gap-2">
      <label className="inline-block w-fit cursor-pointer rounded bg-brand px-3 py-2 text-sm font-medium text-white">
        {busy ? "Uploading..." : "Upload file"}
        <input type="file" onChange={onChange} disabled={busy} className="sr-only" />
      </label>
      {error && (
        <p role="alert" className="text-sm text-red-600">
          {error}
        </p>
      )}
    </div>
  );
}
