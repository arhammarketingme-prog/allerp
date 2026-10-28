-- 0053: ऑर्डर → weavo बिझनेस चॅट पूल (server-to-server, secret ब्राउझरला जात नाही)
create extension if not exists pg_net;

create table if not exists public.app_secrets (key text primary key, value text not null);
alter table public.app_secrets enable row level security;  -- policy नाही = क्लायंटला प्रवेश नाही
revoke all on public.app_secrets from anon, authenticated;

create or replace function public.notify_weavo_on_order()
returns trigger language plpgsql security definer set search_path = public, extensions as $$
declare v_secret text; v_url text; v_anon text; v_shop_email text; v_shop_name text;
begin
  if NEW.items_summary is null then return NEW; end if;
  if TG_OP = 'UPDATE' and OLD.items_summary is not null then return NEW; end if;
  begin   -- कुठलीही चूक झाली तरी ऑर्डर कधीच अडू नये
    select value into v_secret from public.app_secrets where key = 'weavo_bridge_secret';
    select value into v_url    from public.app_secrets where key = 'weavo_bridge_url';
    select value into v_anon   from public.app_secrets where key = 'weavo_anon_key';
    if v_secret is null or v_url is null then return NEW; end if;
    select u.email, b.name into v_shop_email, v_shop_name
      from public.businesses b join auth.users u on u.id = b.owner_id where b.id = NEW.business_id;
    perform net.http_post(
      url := v_url,
      headers := jsonb_build_object('Content-Type','application/json',
                                    'Authorization','Bearer ' || coalesce(v_anon,''),
                                    'x-bridge-secret', v_secret),
      body := jsonb_build_object(
        'order_id', NEW.id, 'shop_email', v_shop_email, 'shop_name', v_shop_name,
        'customer_email', NEW.customer_email, 'customer_name', NEW.customer_name,
        'customer_phone', NEW.customer_phone, 'address', NEW.delivery_address,
        'payment_method', NEW.payment_method, 'total', NEW.total_amount, 'items', NEW.items_summary));
  exception when others then null;
  end;
  return NEW;
end; $$;

drop trigger if exists trg_weavo_order_upd on public.orders;
create trigger trg_weavo_order_upd after update of items_summary on public.orders
  for each row execute function public.notify_weavo_on_order();
drop trigger if exists trg_weavo_order_ins on public.orders;
create trigger trg_weavo_order_ins after insert on public.orders
  for each row execute function public.notify_weavo_on_order();
