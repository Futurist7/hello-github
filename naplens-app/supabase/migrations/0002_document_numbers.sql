-- Distinctive document numbers, e.g. NAP-INV-2610-7KQ3 / NAP-PRP-2610-M4X9.
-- Format: NAP - type - YYMM - 4 random chars (no 0/O/1/I/L lookalikes).
-- Uniqueness is enforced by the existing UNIQUE constraint on `number`.

create or replace function gen_doc_number(kind text) returns text
language plpgsql as $$
declare
  alphabet constant text := '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  suffix text := '';
begin
  for i in 1..4 loop
    suffix := suffix || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
  end loop;
  return 'NAP-' || kind || '-' || to_char(now(), 'YYMM') || '-' || suffix;
end $$;

alter table proposals alter column number set default gen_doc_number('PRP');
alter table invoices  alter column number set default gen_doc_number('INV');
