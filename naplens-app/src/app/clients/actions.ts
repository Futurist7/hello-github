"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

function text(formData: FormData, key: string) {
  const value = String(formData.get(key) ?? "").trim();
  return value === "" ? null : value;
}

export async function createClientRecord(formData: FormData) {
  const name = text(formData, "name");
  if (!name) return;

  const supabase = await createClient();
  const { data, error } = await supabase
    .from("clients")
    .insert({
      name,
      email: text(formData, "email"),
      phone: text(formData, "phone"),
      address: text(formData, "address"),
      notes: text(formData, "notes"),
    })
    .select("id")
    .single();
  if (error) throw new Error(error.message);

  revalidatePath("/clients");
  redirect(`/clients/${data.id}`);
}

export async function deleteClientFile(fileId: string, clientId: string) {
  const supabase = await createClient();
  const { data: file } = await supabase
    .from("client_files")
    .select("path")
    .eq("id", fileId)
    .single();
  if (file) {
    await supabase.storage.from("client-files").remove([file.path]);
    await supabase.from("client_files").delete().eq("id", fileId);
  }
  revalidatePath(`/clients/${clientId}`);
}
