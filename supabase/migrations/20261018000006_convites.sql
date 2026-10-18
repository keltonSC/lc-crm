-- =====================================================================
-- LC CRM · convites
-- Antes, o papel vinha dos metadados do cadastro — qualquer pessoa que se
-- cadastrasse pela API pública poderia se declarar gestor. Agora o papel e a
-- equipe vêm só de um convite criado pelo gestor. Quem se cadastra sem
-- convite fica inativo (sem acesso a nada).
-- =====================================================================

create table convites (
  email      extensions.citext primary key,
  nome       text,
  papel      papel_usuario not null default 'corretor',
  equipe_id  uuid references equipes (id) on delete set null,
  telefone   text,
  criado_por uuid references usuarios (id) on delete set null default auth.uid(),
  usado_em   timestamptz,
  created_at timestamptz not null default now()
);

alter table convites enable row level security;
create policy convites_gestor on convites for all to authenticated
  using (meu_papel() = 'gestor') with check (meu_papel() = 'gestor');

create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
declare
  c convites;
begin
  select * into c from convites where email = new.email and usado_em is null;
  insert into usuarios (id, nome, email, papel, equipe_id, telefone, ativo)
  values (
    new.id,
    coalesce(c.nome, new.raw_user_meta_data ->> 'nome', split_part(new.email, '@', 1)),
    new.email,
    coalesce(c.papel, 'corretor'),
    c.equipe_id,
    coalesce(c.telefone, new.raw_user_meta_data ->> 'telefone'),
    c.email is not null            -- sem convite: entra inativo
  );
  if c.email is not null then
    update convites set usado_em = now() where email = c.email;
  end if;
  return new;
end $$;

revoke execute on function handle_new_user() from public, anon, authenticated;
