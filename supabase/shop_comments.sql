-- Detail toko (barang, kurs, komentar) untuk user yang sudah login.
create or replace function public.shop_detail(p_business_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  if not exists (select 1 from public.businesses b where b.id = p_business_id) then
    raise exception 'shop_not_found';
  end if;

  return jsonb_build_object(
    'items', coalesce((
      select jsonb_agg(
               jsonb_build_object('id', i.id, 'name', i.name, 'price', i.price)
               order by i.created_at, i.id)
        from public.items i
       where i.business_id = p_business_id and i.is_active
    ), '[]'::jsonb),

    'rates', coalesce((
      select jsonb_agg(
               jsonb_build_object(
                 'currency_code', r.currency_code,
                 'foreign_amount', r.foreign_amount,
                 'idr_amount', r.idr_amount,
                 'service_fee_idr', r.service_fee_idr)
               order by r.created_at)
        from public.exchange_rates r
       where r.business_id = p_business_id
    ), '[]'::jsonb),

    'comments', coalesce((
      select jsonb_agg(
               jsonb_build_object(
                 'id', x.id, 'author', x.author, 'body', x.body,
                 'created_at', x.created_at, 'mine', x.mine)
               order by x.created_at desc)
        from (
          select c.id,
                 public.mask_name(p.username) as author,
                 c.body,
                 c.created_at,
                 (c.author_id = v_uid) as mine
            from public.comments c
            join public.profiles p on p.id = c.author_id
           where c.business_id = p_business_id
           order by c.created_at desc
           limit 30
        ) x
    ), '[]'::jsonb)
  );
end
$$;

-- Kirim komentar ke sebuah toko. Komentar masuk ke tabel yang sama dengan
-- yang dibaca dashboard pemilik, sebagai komentar belum dibaca.
create or replace function public.add_store_comment(p_business_id uuid, p_body text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_body text := trim(coalesce(p_body, ''));
  v_owner uuid;
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  if char_length(v_body) < 3 then
    raise exception 'comment_too_short';
  end if;
  if char_length(v_body) > 300 then
    raise exception 'comment_too_long';
  end if;

  select b.owner_id into v_owner
    from public.businesses b
   where b.id = p_business_id;
  if not found then
    raise exception 'shop_not_found';
  end if;
  if v_owner = v_uid then
    raise exception 'comment_own_shop';
  end if;

  -- Maksimal 5 komentar per jam per pengguna.
  if (select count(*) from public.comments c
       where c.author_id = v_uid
         and c.created_at > now() - interval '1 hour') >= 5 then
    raise exception 'comment_rate_limited';
  end if;

  -- Tolak komentar yang persis sama di toko yang sama dalam 24 jam.
  if exists (select 1 from public.comments c
              where c.author_id = v_uid
                and c.business_id = p_business_id
                and c.body = v_body
                and c.created_at > now() - interval '1 day') then
    raise exception 'comment_duplicate';
  end if;

  insert into public.comments (business_id, author_id, body)
  values (p_business_id, v_uid, v_body)
  returning id into v_id;

  return v_id;
end
$$;

-- Hanya pengguna yang login yang boleh memanggil.
revoke all on function public.shop_detail(uuid) from public, anon;
grant execute on function public.shop_detail(uuid) to authenticated;
revoke all on function public.add_store_comment(uuid, text) from public, anon;
grant execute on function public.add_store_comment(uuid, text) to authenticated;

-- Opsional, mempercepat daftar komentar dan batas frekuensi.
create index if not exists comments_business_created_idx
  on public.comments (business_id, created_at desc);
create index if not exists comments_author_created_idx
  on public.comments (author_id, created_at desc);
