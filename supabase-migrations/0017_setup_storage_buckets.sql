-- 0017_setup_storage_buckets.sql
-- Create storage buckets for ads and products if they do not exist

insert into storage.buckets (id, name, public)
values 
  ('ads-media', 'ads-media', true),
  ('product-images', 'product-images', true)
on conflict (id) do update set public = true;

-- Allow public read access to all uploaded media
create policy "Public Access to Ads Media"
on storage.objects for select
using ( bucket_id = 'ads-media' );

create policy "Public Access to Product Images"
on storage.objects for select
using ( bucket_id = 'product-images' );

-- Allow authenticated users to upload files
create policy "Authenticated Users Can Upload Ads Media"
on storage.objects for insert
to authenticated
with check ( bucket_id = 'ads-media' );

create policy "Authenticated Users Can Upload Product Images"
on storage.objects for insert
to authenticated
with check ( bucket_id = 'product-images' );
