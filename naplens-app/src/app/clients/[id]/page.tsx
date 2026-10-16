import Link from "next/link";
import { notFound } from "next/navigation";
import { Suspense } from "react";
import { createClient } from "@/lib/supabase/server";
import { deleteClientFile } from "../actions";
import { FileUpload } from "./upload";

function formatSize(bytes: number | null) {
  if (bytes == null) return "";
  return bytes < 1024 * 1024
    ? `${Math.max(1, Math.round(bytes / 1024))} KB`
    : `${(bytes / 1024 / 1024).toFixed(1)} MB`;
}

export default function ClientPage({ params }: PageProps<"/clients/[id]">) {
  return (
    <main className="mx-auto w-full max-w-3xl px-4 py-10 sm:px-6">
      <Link href="/clients" className="text-sm underline opacity-70">
        All clients
      </Link>
      <Suspense fallback={<p className="mt-6 text-sm opacity-70">Loading...</p>}>
        <ClientContent params={params} />
      </Suspense>
    </main>
  );
}

async function ClientContent({ params }: { params: PageProps<"/clients/[id]">["params"] }) {
  const { id } = await params;
  const supabase = await createClient();

  const { data: client } = await supabase
    .from("clients")
    .select("id, name, email, phone, address, notes")
    .eq("id", id)
    .single();
  if (!client) notFound();

  const { data: files } = await supabase
    .from("client_files")
    .select("id, name, path, size_bytes, created_at")
    .eq("client_id", id)
    .order("created_at", { ascending: false });

  const { data: signed } = files?.length
    ? await supabase.storage
        .from("client-files")
        .createSignedUrls(files.map((f) => f.path), 3600)
    : { data: [] };
  const urlByPath = new Map((signed ?? []).map((s) => [s.path, s.signedUrl]));

  const details: [string, string | null][] = [
    ["Email", client.email],
    ["Phone", client.phone],
    ["Address", client.address],
    ["Notes", client.notes],
  ];

  return (
    <>
      <h1 className="mt-3 text-2xl font-semibold">{client.name}</h1>

      <dl className="mt-4 grid grid-cols-[6rem_1fr] gap-y-1 text-sm">
        {details
          .filter(([, v]) => v)
          .map(([k, v]) => (
            <div key={k} className="contents">
              <dt className="opacity-60">{k}</dt>
              <dd className="whitespace-pre-wrap">{v}</dd>
            </div>
          ))}
      </dl>

      <section className="mt-10">
        <div className="flex items-center justify-between">
          <h2 className="font-medium">Files and receipts</h2>
          <FileUpload clientId={client.id} />
        </div>

        {files?.length ? (
          <ul className="mt-4 divide-y divide-black/10 rounded-lg border border-black/10 dark:divide-white/15 dark:border-white/15">
            {files.map((f) => (
              <li key={f.id} className="flex items-center justify-between gap-3 px-4 py-3 text-sm">
                <a
                  href={urlByPath.get(f.path) ?? undefined}
                  target="_blank"
                  rel="noreferrer"
                  className="min-w-0 truncate underline"
                >
                  {f.name}
                </a>
                <span className="flex shrink-0 items-center gap-3">
                  <span className="opacity-60">{formatSize(f.size_bytes)}</span>
                  <form action={deleteClientFile.bind(null, f.id, client.id)}>
                    <button className="text-red-600 underline">Delete</button>
                  </form>
                </span>
              </li>
            ))}
          </ul>
        ) : (
          <p className="mt-4 text-sm opacity-70">No files uploaded yet.</p>
        )}
      </section>
    </>
  );
}
