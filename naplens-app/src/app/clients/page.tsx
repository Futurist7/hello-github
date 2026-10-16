import Link from "next/link";
import { Suspense } from "react";
import { createClient } from "@/lib/supabase/server";
import { createClientRecord } from "./actions";

const input =
  "rounded border border-black/20 bg-transparent px-3 py-2 text-sm dark:border-white/25";

export default function ClientsPage() {
  return (
    <main className="mx-auto w-full max-w-5xl px-4 py-10 sm:px-6">
      <Link href="/" className="text-sm underline opacity-70">
        Back to hub
      </Link>
      <h1 className="mt-3 text-2xl font-semibold">Clients</h1>
      <Suspense fallback={<p className="mt-8 text-sm opacity-70">Loading...</p>}>
        <ClientsContent />
      </Suspense>
    </main>
  );
}

async function ClientsContent() {
  const supabase = await createClient();
  const { data: clients } = await supabase
    .from("clients")
    .select("id, name, email, phone")
    .order("name");

  return (
      <div className="mt-8 grid gap-8 lg:grid-cols-[1fr_20rem]">
        <section>
          {clients?.length ? (
            <ul className="divide-y divide-black/10 rounded-lg border border-black/10 dark:divide-white/15 dark:border-white/15">
              {clients.map((c) => (
                <li key={c.id}>
                  <Link
                    href={`/clients/${c.id}`}
                    className="flex flex-col px-4 py-3 hover:bg-black/[.03] dark:hover:bg-white/[.05]"
                  >
                    <span className="font-medium">{c.name}</span>
                    <span className="text-sm opacity-70">
                      {[c.email, c.phone].filter(Boolean).join(" · ") || "No contact details"}
                    </span>
                  </Link>
                </li>
              ))}
            </ul>
          ) : (
            <p className="text-sm opacity-70">No clients yet. Add your first one.</p>
          )}
        </section>

        <form action={createClientRecord} className="flex flex-col gap-3">
          <h2 className="font-medium">New client</h2>
          <input name="name" required placeholder="Name *" className={input} />
          <input name="email" type="email" placeholder="Email" className={input} />
          <input name="phone" placeholder="Phone" className={input} />
          <input name="address" placeholder="Address" className={input} />
          <textarea name="notes" placeholder="Notes" rows={3} className={input} />
          <button className="rounded bg-brand px-3 py-2 text-sm font-medium text-white">
            Add client
          </button>
        </form>
      </div>
  );
}
