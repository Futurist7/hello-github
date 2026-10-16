"use client";

import { useActionState } from "react";
import { signIn } from "./actions";

export default function LoginPage() {
  const [state, action, pending] = useActionState(signIn, undefined);

  return (
    <main className="mx-auto flex w-full max-w-sm flex-1 flex-col justify-center px-4 py-16">
      <p className="text-sm font-medium uppercase tracking-wide text-brand">
        Naplens Digital
      </p>
      <h1 className="mt-1 text-2xl font-semibold">Sign in</h1>

      <form action={action} className="mt-6 flex flex-col gap-4">
        <label className="flex flex-col gap-1 text-sm">
          Email
          <input
            name="email"
            type="email"
            required
            autoComplete="email"
            className="rounded border border-black/20 bg-transparent px-3 py-2 dark:border-white/25"
          />
        </label>
        <label className="flex flex-col gap-1 text-sm">
          Password
          <input
            name="password"
            type="password"
            required
            autoComplete="current-password"
            className="rounded border border-black/20 bg-transparent px-3 py-2 dark:border-white/25"
          />
        </label>
        {state?.error && (
          <p role="alert" className="text-sm text-red-600">
            {state.error}
          </p>
        )}
        <button
          disabled={pending}
          className="rounded bg-brand px-3 py-2 text-sm font-medium text-white disabled:opacity-60"
        >
          {pending ? "Signing in..." : "Sign in"}
        </button>
      </form>
    </main>
  );
}
