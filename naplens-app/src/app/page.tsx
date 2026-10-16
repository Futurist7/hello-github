const modules = [
  { name: "Clients", note: "Records, files and receipts", phase: "Phase 2" },
  { name: "Proposals & Quotes", note: "Offer builder with PDF export", phase: "Phase 3" },
  { name: "Invoices", note: "GHS and USD, status tracking", phase: "Phase 3" },
  { name: "Payments", note: "MoMo checkout and bank transfers", phase: "Phase 4" },
  { name: "Retainers", note: "Recurring invoice schedules", phase: "Phase 5" },
  { name: "Expenses & Reports", note: "P&L, cash view, receivables", phase: "Phase 6" },
];

export default function Home() {
  return (
    <main className="mx-auto w-full max-w-5xl px-4 py-10 sm:px-6">
      <header className="mb-10">
        <p className="text-sm font-medium uppercase tracking-wide text-brand">
          Naplens Digital
        </p>
        <h1 className="mt-1 text-3xl font-semibold tracking-tight">
          Business Hub
        </h1>
        <p className="mt-2 text-sm opacity-70">
          Proposals, invoices, payments and books in one place.
        </p>
      </header>

      <section className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {modules.map((m) => (
          <article
            key={m.name}
            className="rounded-lg border border-black/10 p-5 dark:border-white/15"
          >
            <h2 className="font-medium">{m.name}</h2>
            <p className="mt-1 text-sm opacity-70">{m.note}</p>
            <span className="mt-4 inline-block rounded bg-brand/10 px-2 py-0.5 text-xs text-brand">
              {m.phase}
            </span>
          </article>
        ))}
      </section>
    </main>
  );
}
