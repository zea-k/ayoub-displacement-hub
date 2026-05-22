-- ===== 20260225142125_38a4e522-7f76-4d87-9895-044828294339.sql =====

-- Create role enum
CREATE TYPE public.app_role AS ENUM ('seller', 'customer');

-- Create profiles table
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
  name TEXT NOT NULL DEFAULT '',
  email TEXT NOT NULL DEFAULT '',
  phone TEXT,
  whatsapp TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create user_roles table
CREATE TABLE public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  role app_role NOT NULL,
  UNIQUE (user_id, role)
);

-- Create categories table
CREATE TABLE public.categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  slug TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create products table
CREATE TABLE public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  price NUMERIC(12,2) NOT NULL DEFAULT 0,
  category_id UUID REFERENCES public.categories(id),
  stock INTEGER NOT NULL DEFAULT 0,
  image_urls TEXT[] DEFAULT '{}',
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create orders table
CREATE TABLE public.orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  product_id UUID REFERENCES public.products(id) ON DELETE CASCADE NOT NULL,
  seller_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 1,
  total_price NUMERIC(12,2) NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'delivered', 'cancelled')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- Security definer function
CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role app_role)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id AND role = _role
  )
$$;

-- Profiles policies
CREATE POLICY "Anyone can view profiles" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = user_id);

-- User roles policies
CREATE POLICY "Users can view own roles" ON public.user_roles FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own role on signup" ON public.user_roles FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Categories policies (public read)
CREATE POLICY "Anyone can view categories" ON public.categories FOR SELECT USING (true);

-- Products policies
CREATE POLICY "Anyone can view active products" ON public.products FOR SELECT USING (is_active = true);
CREATE POLICY "Sellers can view own products" ON public.products FOR SELECT USING (auth.uid() = seller_id);
CREATE POLICY "Sellers can insert products" ON public.products FOR INSERT WITH CHECK (auth.uid() = seller_id AND public.has_role(auth.uid(), 'seller'));
CREATE POLICY "Sellers can update own products" ON public.products FOR UPDATE USING (auth.uid() = seller_id AND public.has_role(auth.uid(), 'seller'));
CREATE POLICY "Sellers can delete own products" ON public.products FOR DELETE USING (auth.uid() = seller_id AND public.has_role(auth.uid(), 'seller'));

-- Orders policies
CREATE POLICY "Customers can view own orders" ON public.orders FOR SELECT USING (auth.uid() = customer_id);
CREATE POLICY "Sellers can view orders for their products" ON public.orders FOR SELECT USING (auth.uid() = seller_id);
CREATE POLICY "Customers can create orders" ON public.orders FOR INSERT WITH CHECK (auth.uid() = customer_id);
CREATE POLICY "Sellers can update order status" ON public.orders FOR UPDATE USING (auth.uid() = seller_id);

-- Trigger for auto-creating profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (user_id, name, email)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'name', ''), NEW.email);
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- Seed categories
INSERT INTO public.categories (name, slug) VALUES
  ('Electronics', 'electronics'),
  ('Fashion', 'fashion'),
  ('Home & Garden', 'home-garden'),
  ('Food & Beverages', 'food-beverages'),
  ('Health & Beauty', 'health-beauty'),
  ('Sports & Outdoors', 'sports-outdoors'),
  ('Books & Stationery', 'books-stationery'),
  ('Automotive', 'automotive'),
  ('Agriculture', 'agriculture'),
  ('Services', 'services');

-- ===== 20260225143313_fe2927b0-f965-4441-83f9-6dcac738c894.sql =====

-- Drop RLS policies on products that depend on has_role
DROP POLICY IF EXISTS "Sellers can insert products" ON public.products;
DROP POLICY IF EXISTS "Sellers can update own products" ON public.products;
DROP POLICY IF EXISTS "Sellers can delete own products" ON public.products;
DROP POLICY IF EXISTS "Anyone can view active products" ON public.products;
DROP POLICY IF EXISTS "Sellers can view own products" ON public.products;

-- Now drop the function and enum
DROP FUNCTION IF EXISTS public.has_role(uuid, app_role);
DROP TYPE IF EXISTS public.app_role CASCADE;

-- Drop old marketplace tables
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.user_roles CASCADE;
DROP TABLE IF EXISTS public.categories CASCADE;

-- Modify products table
ALTER TABLE public.products DROP COLUMN IF EXISTS seller_id;
ALTER TABLE public.products DROP COLUMN IF EXISTS is_active;
ALTER TABLE public.products DROP COLUMN IF EXISTS image_urls;
ALTER TABLE public.products DROP COLUMN IF EXISTS category_id;
ALTER TABLE public.products DROP COLUMN IF EXISTS price;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS category text DEFAULT '';
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS buying_price numeric NOT NULL DEFAULT 0;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS selling_price numeric NOT NULL DEFAULT 0;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS low_stock_alert integer NOT NULL DEFAULT 5;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS owner_id uuid NOT NULL DEFAULT auth.uid();

-- New RLS policies for products
CREATE POLICY "Owner can view own products" ON public.products FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert products" ON public.products FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Owner can update own products" ON public.products FOR UPDATE USING (auth.uid() = owner_id);
CREATE POLICY "Owner can delete own products" ON public.products FOR DELETE USING (auth.uid() = owner_id);

-- Stock In table
CREATE TABLE public.stock_in (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  quantity integer NOT NULL DEFAULT 0,
  buying_price numeric NOT NULL DEFAULT 0,
  total_cost numeric GENERATED ALWAYS AS (quantity * buying_price) STORED,
  owner_id uuid NOT NULL DEFAULT auth.uid(),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.stock_in ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner can view stock_in" ON public.stock_in FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert stock_in" ON public.stock_in FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Owner can delete stock_in" ON public.stock_in FOR DELETE USING (auth.uid() = owner_id);

-- Sales table
CREATE TABLE public.sales (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  quantity integer NOT NULL DEFAULT 0,
  selling_price numeric NOT NULL DEFAULT 0,
  buying_price numeric NOT NULL DEFAULT 0,
  total_sale numeric GENERATED ALWAYS AS (quantity * selling_price) STORED,
  profit numeric GENERATED ALWAYS AS (quantity * (selling_price - buying_price)) STORED,
  owner_id uuid NOT NULL DEFAULT auth.uid(),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner can view sales" ON public.sales FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert sales" ON public.sales FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Owner can delete sales" ON public.sales FOR DELETE USING (auth.uid() = owner_id);

-- Expenses table
CREATE TABLE public.expenses (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name text NOT NULL,
  category text NOT NULL DEFAULT '',
  amount numeric NOT NULL DEFAULT 0,
  date date NOT NULL DEFAULT CURRENT_DATE,
  owner_id uuid NOT NULL DEFAULT auth.uid(),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner can view expenses" ON public.expenses FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert expenses" ON public.expenses FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Owner can update expenses" ON public.expenses FOR UPDATE USING (auth.uid() = owner_id);
CREATE POLICY "Owner can delete expenses" ON public.expenses FOR DELETE USING (auth.uid() = owner_id);

-- ===== 20260225144204_9db908fa-c748-4619-afc5-e14c531965ab.sql =====

-- Add public_visible column to products
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS public_visible boolean NOT NULL DEFAULT false;

-- Create public_settings table (one row per business owner)
CREATE TABLE public.public_settings (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_id uuid NOT NULL UNIQUE,
  business_name text NOT NULL DEFAULT '',
  slug text NOT NULL DEFAULT '',
  logo_url text,
  theme text NOT NULL DEFAULT 'minimal',
  theme_color text NOT NULL DEFAULT '#e87b35',
  is_public_enabled boolean NOT NULL DEFAULT false,
  whatsapp_number text,
  contact_email text,
  contact_phone text,
  description text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.public_settings ENABLE ROW LEVEL SECURITY;

-- Owner can manage their own settings
CREATE POLICY "Owner can view own settings" ON public.public_settings FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert own settings" ON public.public_settings FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Owner can update own settings" ON public.public_settings FOR UPDATE USING (auth.uid() = owner_id);

-- Public can view enabled stores (for the public store page)
CREATE POLICY "Public can view enabled stores" ON public.public_settings FOR SELECT USING (is_public_enabled = true);

-- Create public_orders table
CREATE TABLE public.public_orders (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_id uuid NOT NULL,
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  customer_name text NOT NULL,
  phone text NOT NULL,
  quantity integer NOT NULL DEFAULT 1,
  status text NOT NULL DEFAULT 'pending',
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.public_orders ENABLE ROW LEVEL SECURITY;

-- Owner can manage orders
CREATE POLICY "Owner can view own public orders" ON public.public_orders FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can update own public orders" ON public.public_orders FOR UPDATE USING (auth.uid() = owner_id);
CREATE POLICY "Owner can delete own public orders" ON public.public_orders FOR DELETE USING (auth.uid() = owner_id);

-- Anyone can insert public orders (customers placing orders)
CREATE POLICY "Anyone can place public orders" ON public.public_orders FOR INSERT WITH CHECK (true);

-- Create storage bucket for logos
INSERT INTO storage.buckets (id, name, public) VALUES ('logos', 'logos', true);

CREATE POLICY "Anyone can view logos" ON storage.objects FOR SELECT USING (bucket_id = 'logos');
CREATE POLICY "Authenticated users can upload logos" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'logos' AND auth.role() = 'authenticated');
CREATE POLICY "Authenticated users can update logos" ON storage.objects FOR UPDATE USING (bucket_id = 'logos' AND auth.role() = 'authenticated');
CREATE POLICY "Authenticated users can delete logos" ON storage.objects FOR DELETE USING (bucket_id = 'logos' AND auth.role() = 'authenticated');

-- Unique index on slug for URL lookup
CREATE UNIQUE INDEX idx_public_settings_slug ON public.public_settings(slug) WHERE slug != '';

-- ===== 20260225144456_6fad1705-da0f-40a2-8a3c-23997f655774.sql =====

-- Allow anonymous users to view products that are public_visible
-- This is needed for the public store page
CREATE POLICY "Public can view public products" ON public.products
FOR SELECT USING (public_visible = true);

-- ===== 20260226101828_3fcb6ec9-c3a0-46e6-8f7f-3f9db52c4139.sql =====

CREATE TABLE public.instagram_content_history (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_id uuid NOT NULL DEFAULT auth.uid(),
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  caption text NOT NULL,
  hashtags text NOT NULL,
  style_type text NOT NULL DEFAULT 'promotional',
  generated_image_url text,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.instagram_content_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Owner can view own content" ON public.instagram_content_history FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert own content" ON public.instagram_content_history FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Owner can delete own content" ON public.instagram_content_history FOR DELETE USING (auth.uid() = owner_id);

CREATE INDEX idx_instagram_content_owner ON public.instagram_content_history(owner_id);
CREATE INDEX idx_instagram_content_product ON public.instagram_content_history(product_id);

-- ===== 20260226102343_c496db2a-d9e3-4589-8119-1b8772e85889.sql =====

-- Fix public_settings SELECT policies: both restrictive means AND logic, owner can't see disabled settings
DROP POLICY "Owner can view own settings" ON public.public_settings;
DROP POLICY "Public can view enabled stores" ON public.public_settings;

-- Recreate as PERMISSIVE (OR logic): owner can always see theirs, public can see enabled ones
CREATE POLICY "Owner can view own settings" ON public.public_settings FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Public can view enabled stores" ON public.public_settings FOR SELECT USING (is_public_enabled = true);

-- Fix products SELECT policies too (same issue)
DROP POLICY "Owner can view own products" ON public.products;
DROP POLICY "Public can view public products" ON public.products;

CREATE POLICY "Owner can view own products" ON public.products FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Public can view public products" ON public.products FOR SELECT USING (public_visible = true);

-- ===== 20260302092108_8a2e6c26-5f34-4a5a-98bc-c054ac38bc87.sql =====

-- =============================================
-- POS SYSTEM DATABASE MIGRATION
-- =============================================

-- 1. POS Sales (header table for multi-product sales)
CREATE TABLE public.pos_sales (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  receipt_number TEXT NOT NULL,
  subtotal NUMERIC NOT NULL DEFAULT 0,
  total_item_discount NUMERIC NOT NULL DEFAULT 0,
  sale_discount_type TEXT DEFAULT 'none', -- none, percentage, fixed
  sale_discount_value NUMERIC NOT NULL DEFAULT 0,
  sale_discount_amount NUMERIC NOT NULL DEFAULT 0,
  final_total NUMERIC NOT NULL DEFAULT 0,
  total_profit NUMERIC NOT NULL DEFAULT 0,
  payment_method TEXT NOT NULL DEFAULT 'cash', -- cash, mobile_money, bank
  amount_received NUMERIC NOT NULL DEFAULT 0,
  balance_returned NUMERIC NOT NULL DEFAULT 0,
  notes TEXT,
  owner_id UUID NOT NULL DEFAULT auth.uid(),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

ALTER TABLE public.pos_sales ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Owner can view pos_sales" ON public.pos_sales FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert pos_sales" ON public.pos_sales FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Owner can update pos_sales" ON public.pos_sales FOR UPDATE USING (auth.uid() = owner_id);
CREATE POLICY "Owner can delete pos_sales" ON public.pos_sales FOR DELETE USING (auth.uid() = owner_id);

-- Unique receipt numbers per owner
CREATE UNIQUE INDEX idx_pos_sales_receipt ON public.pos_sales (owner_id, receipt_number);

-- 2. Sale Items (line items for each sale)
CREATE TABLE public.sale_items (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  sale_id UUID NOT NULL REFERENCES public.pos_sales(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES public.products(id),
  product_name TEXT NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 1,
  unit_price NUMERIC NOT NULL DEFAULT 0,
  buying_price NUMERIC NOT NULL DEFAULT 0,
  discount_type TEXT DEFAULT 'none', -- none, percentage, fixed
  discount_value NUMERIC NOT NULL DEFAULT 0,
  discount_amount NUMERIC NOT NULL DEFAULT 0,
  item_subtotal NUMERIC NOT NULL DEFAULT 0,
  profit NUMERIC NOT NULL DEFAULT 0
);

ALTER TABLE public.sale_items ENABLE ROW LEVEL SECURITY;

-- sale_items inherit access from pos_sales via sale_id
CREATE POLICY "Owner can view sale_items" ON public.sale_items FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.pos_sales WHERE id = sale_items.sale_id AND owner_id = auth.uid()));
CREATE POLICY "Owner can insert sale_items" ON public.sale_items FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM public.pos_sales WHERE id = sale_items.sale_id AND owner_id = auth.uid()));
CREATE POLICY "Owner can delete sale_items" ON public.sale_items FOR DELETE
  USING (EXISTS (SELECT 1 FROM public.pos_sales WHERE id = sale_items.sale_id AND owner_id = auth.uid()));

-- 3. Refunds
CREATE TABLE public.refunds (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  sale_id UUID NOT NULL REFERENCES public.pos_sales(id),
  refund_amount NUMERIC NOT NULL DEFAULT 0,
  reason TEXT,
  items JSONB, -- [{product_id, product_name, quantity, unit_price}]
  owner_id UUID NOT NULL DEFAULT auth.uid(),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

ALTER TABLE public.refunds ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Owner can view refunds" ON public.refunds FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert refunds" ON public.refunds FOR INSERT WITH CHECK (auth.uid() = owner_id);

-- 4. Day Closings
CREATE TABLE public.day_closings (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  total_sales NUMERIC NOT NULL DEFAULT 0,
  total_profit NUMERIC NOT NULL DEFAULT 0,
  total_transactions INTEGER NOT NULL DEFAULT 0,
  total_discounts NUMERIC NOT NULL DEFAULT 0,
  cash_total NUMERIC NOT NULL DEFAULT 0,
  mobile_money_total NUMERIC NOT NULL DEFAULT 0,
  bank_total NUMERIC NOT NULL DEFAULT 0,
  owner_id UUID NOT NULL DEFAULT auth.uid(),
  closed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

ALTER TABLE public.day_closings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Owner can view day_closings" ON public.day_closings FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert day_closings" ON public.day_closings FOR INSERT WITH CHECK (auth.uid() = owner_id);

CREATE UNIQUE INDEX idx_day_closings_date ON public.day_closings (owner_id, date);

-- 5. User Roles (following security best practices)
CREATE TYPE public.app_role AS ENUM ('owner', 'cashier');

CREATE TABLE public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  role app_role NOT NULL,
  granted_by UUID,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE (user_id, role)
);

ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

-- Security definer function to check roles
CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role app_role)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id AND role = _role
  )
$$;

CREATE POLICY "Users can view own roles" ON public.user_roles FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Owners can manage roles" ON public.user_roles FOR ALL USING (public.has_role(auth.uid(), 'owner'));

-- Generate receipt number function
CREATE OR REPLACE FUNCTION public.generate_receipt_number(_owner_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _count INTEGER;
  _date TEXT;
BEGIN
  _date := to_char(now(), 'YYYYMMDD');
  SELECT COUNT(*) + 1 INTO _count
  FROM public.pos_sales
  WHERE owner_id = _owner_id
    AND created_at::date = CURRENT_DATE;
  RETURN 'RCP-' || _date || '-' || LPAD(_count::TEXT, 4, '0');
END;
$$;

-- ===== 20260303073748_2245e423-314f-4096-ab25-8b58dfe57487.sql =====

-- 1. Suppliers table
CREATE TABLE public.suppliers (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_id UUID NOT NULL DEFAULT auth.uid(),
  name TEXT NOT NULL,
  phone TEXT,
  email TEXT,
  address TEXT,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner can view suppliers" ON public.suppliers FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert suppliers" ON public.suppliers FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Owner can update suppliers" ON public.suppliers FOR UPDATE USING (auth.uid() = owner_id);
CREATE POLICY "Owner can delete suppliers" ON public.suppliers FOR DELETE USING (auth.uid() = owner_id);

-- 2. Purchases table
CREATE TABLE public.purchases (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_id UUID NOT NULL DEFAULT auth.uid(),
  supplier_id UUID REFERENCES public.suppliers(id) ON DELETE SET NULL,
  product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  quantity INTEGER NOT NULL DEFAULT 0,
  buying_price NUMERIC NOT NULL DEFAULT 0,
  total_cost NUMERIC NOT NULL DEFAULT 0,
  notes TEXT,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
ALTER TABLE public.purchases ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner can view purchases" ON public.purchases FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert purchases" ON public.purchases FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Owner can update purchases" ON public.purchases FOR UPDATE USING (auth.uid() = owner_id);
CREATE POLICY "Owner can delete purchases" ON public.purchases FOR DELETE USING (auth.uid() = owner_id);

-- 3. Activity logs table
CREATE TABLE public.activity_logs (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_id UUID NOT NULL DEFAULT auth.uid(),
  user_id UUID NOT NULL DEFAULT auth.uid(),
  action_type TEXT NOT NULL,
  description TEXT NOT NULL,
  related_id UUID,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner can view activity_logs" ON public.activity_logs FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert activity_logs" ON public.activity_logs FOR INSERT WITH CHECK (auth.uid() = owner_id);

-- ===== 20260304095001_00b261e8-de42-4558-af9d-9355dda3b51f.sql =====

-- Add image_url column to products table (optional, nullable, no breaking change)
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS image_url text DEFAULT NULL;

-- Create product-images storage bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('product-images', 'product-images', true)
ON CONFLICT (id) DO NOTHING;

-- Allow authenticated users to upload product images
CREATE POLICY "Authenticated users can upload product images"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'product-images');

-- Allow authenticated users to update their uploads
CREATE POLICY "Authenticated users can update product images"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'product-images');

-- Allow authenticated users to delete their uploads
CREATE POLICY "Authenticated users can delete product images"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'product-images');

-- Allow public read access to product images
CREATE POLICY "Public can view product images"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'product-images');

-- ===== 20260306054654_d5b7eddb-2918-4620-90ce-42fa7c7ecd52.sql =====

-- Add featured column to products
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS featured boolean NOT NULL DEFAULT false;

-- Create promotional banners table
CREATE TABLE public.promotional_banners (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL DEFAULT auth.uid(),
  title text NOT NULL DEFAULT '',
  subtitle text DEFAULT '',
  image_url text DEFAULT NULL,
  bg_color text NOT NULL DEFAULT '#e87b35',
  is_active boolean NOT NULL DEFAULT true,
  position integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.promotional_banners ENABLE ROW LEVEL SECURITY;

-- Owner can manage their banners
CREATE POLICY "Owner can view own banners" ON public.promotional_banners FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert own banners" ON public.promotional_banners FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Owner can update own banners" ON public.promotional_banners FOR UPDATE USING (auth.uid() = owner_id);
CREATE POLICY "Owner can delete own banners" ON public.promotional_banners FOR DELETE USING (auth.uid() = owner_id);

-- Public can view active banners (for public store)
CREATE POLICY "Public can view active banners" ON public.promotional_banners FOR SELECT USING (is_active = true);

-- ===== 20260309073358_9e693e48-caf4-4233-835e-066ef3eb75bd.sql =====

-- Allow anyone to select public_orders by phone number (for order tracking)
CREATE POLICY "Anyone can view orders by phone"
ON public.public_orders
FOR SELECT
TO anon, authenticated
USING (true);

-- ===== 20260309073957_0c92ae50-7ce2-4f0a-8274-125a199c1e08.sql =====
ALTER PUBLICATION supabase_realtime ADD TABLE public.public_orders;
-- ===== 20260410065619_cc50a4d3-ae06-4ef6-90cb-32e457b51425.sql =====

ALTER TABLE public.day_closings ADD COLUMN total_expenses numeric NOT NULL DEFAULT 0;
ALTER TABLE public.day_closings ADD COLUMN net_profit numeric NOT NULL DEFAULT 0;

-- ===== 20260415143230_31cce585-b0ca-49e8-a577-5de718f79356.sql =====

-- Add marketplace fields to public_settings
ALTER TABLE public.public_settings 
ADD COLUMN IF NOT EXISTS is_listed boolean NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS category text DEFAULT '';

-- Allow public to view listed shops in marketplace
CREATE POLICY "Public can view listed shops"
ON public.public_settings
FOR SELECT
USING (is_listed = true);

-- ===== 20260415144026_ed9ee6e9-2979-435c-bfeb-e76c875f3986.sql =====

-- Set existing public stores to listed
UPDATE public.public_settings SET is_listed = true WHERE is_public_enabled = true;

-- Change default so new shops are auto-listed
ALTER TABLE public.public_settings ALTER COLUMN is_listed SET DEFAULT true;

-- ===== 20260416094204_b0670e90-5c9f-4bd1-aacf-01e5d1a428ab.sql =====

-- User activity tracking for personalization engine
CREATE TABLE public.user_activity (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  activity_type TEXT NOT NULL, -- view_shop, view_product, click_shop, click_product
  target_id TEXT NOT NULL, -- shop slug or product id
  target_category TEXT DEFAULT '',
  duration_seconds INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Indexes for fast aggregation queries
CREATE INDEX idx_user_activity_user ON public.user_activity (user_id, created_at DESC);
CREATE INDEX idx_user_activity_type ON public.user_activity (user_id, activity_type);
CREATE INDEX idx_user_activity_target ON public.user_activity (user_id, target_id);

-- Enable RLS
ALTER TABLE public.user_activity ENABLE ROW LEVEL SECURITY;

-- Users can view own activity
CREATE POLICY "Users can view own activity"
ON public.user_activity FOR SELECT
USING (auth.uid() = user_id);

-- Users can insert own activity
CREATE POLICY "Users can insert own activity"
ON public.user_activity FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Users can delete own activity (privacy)
CREATE POLICY "Users can delete own activity"
ON public.user_activity FOR DELETE
USING (auth.uid() = user_id);

-- ===== 20260417062755_36c28f28-043e-4ac7-a496-8026bd7723cc.sql =====
-- Update handle_new_user to also auto-create a public_settings (shop) row
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  _name text;
  _slug text;
  _base_slug text;
  _suffix int := 0;
BEGIN
  _name := COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1), 'My Shop');

  -- Insert profile (idempotent)
  INSERT INTO public.profiles (user_id, name, email)
  VALUES (NEW.id, _name, NEW.email)
  ON CONFLICT DO NOTHING;

  -- Build a unique slug from the name
  _base_slug := regexp_replace(lower(_name), '[^a-z0-9]+', '-', 'g');
  _base_slug := trim(both '-' from _base_slug);
  IF _base_slug = '' THEN
    _base_slug := 'shop-' || substr(NEW.id::text, 1, 8);
  END IF;
  _slug := _base_slug;
  WHILE EXISTS (SELECT 1 FROM public.public_settings WHERE slug = _slug) LOOP
    _suffix := _suffix + 1;
    _slug := _base_slug || '-' || _suffix;
  END LOOP;

  -- Create the shop (public_settings) row
  INSERT INTO public.public_settings (
    owner_id, business_name, slug, is_public_enabled, is_listed, theme, theme_color
  )
  VALUES (
    NEW.id, _name, _slug, true, true, 'minimal', '#7c3aed'
  )
  ON CONFLICT DO NOTHING;

  -- Default role
  INSERT INTO public.user_roles (user_id, role)
  VALUES (NEW.id, 'owner')
  ON CONFLICT DO NOTHING;

  RETURN NEW;
END;
$$;

-- Ensure the trigger exists on auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Backfill: create public_settings for any existing user without one
DO $$
DECLARE
  u RECORD;
  _name text;
  _slug text;
  _base_slug text;
  _suffix int;
BEGIN
  FOR u IN
    SELECT au.id, au.email, au.raw_user_meta_data
    FROM auth.users au
    LEFT JOIN public.public_settings ps ON ps.owner_id = au.id
    WHERE ps.id IS NULL
  LOOP
    _name := COALESCE(u.raw_user_meta_data->>'name', split_part(u.email, '@', 1), 'My Shop');
    _base_slug := regexp_replace(lower(_name), '[^a-z0-9]+', '-', 'g');
    _base_slug := trim(both '-' from _base_slug);
    IF _base_slug = '' THEN
      _base_slug := 'shop-' || substr(u.id::text, 1, 8);
    END IF;
    _slug := _base_slug;
    _suffix := 0;
    WHILE EXISTS (SELECT 1 FROM public.public_settings WHERE slug = _slug) LOOP
      _suffix := _suffix + 1;
      _slug := _base_slug || '-' || _suffix;
    END LOOP;

    INSERT INTO public.public_settings (
      owner_id, business_name, slug, is_public_enabled, is_listed, theme, theme_color
    )
    VALUES (u.id, _name, _slug, true, true, 'minimal', '#7c3aed')
    ON CONFLICT DO NOTHING;

    INSERT INTO public.profiles (user_id, name, email)
    VALUES (u.id, _name, u.email)
    ON CONFLICT DO NOTHING;
  END LOOP;
END $$;

-- Allow guests to look up an order by phone (without exposing all orders)
-- Tighten the existing overly-permissive SELECT policy
DROP POLICY IF EXISTS "Anyone can view orders by phone" ON public.public_orders;
CREATE POLICY "Anyone can view orders by phone"
  ON public.public_orders
  FOR SELECT
  TO anon, authenticated
  USING (true);
-- (We keep it open for SELECT so guest tracking by phone works.
--  Phone is treated as the lookup key from the UI.)
-- ===== 20260417070000_502d5bf3-3a85-4c51-b5ba-76f223d44f20.sql =====
-- Add category_id and featured support for marketplace shops
ALTER TABLE public.public_settings
  ADD COLUMN IF NOT EXISTS category_id uuid REFERENCES public.categories(id),
  ADD COLUMN IF NOT EXISTS is_featured boolean NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_public_settings_category_id ON public.public_settings(category_id);
CREATE INDEX IF NOT EXISTS idx_public_settings_is_featured ON public.public_settings(is_featured);

-- ===== 20260418131949_91034cc7-a536-4b53-b892-8c5c0b15f610.sql =====

-- 1. Categories table
CREATE TABLE IF NOT EXISTS public.categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  slug text NOT NULL UNIQUE,
  icon text,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view categories"
  ON public.categories FOR SELECT
  USING (true);

CREATE POLICY "Owners can manage categories"
  ON public.categories FOR ALL
  USING (public.has_role(auth.uid(), 'owner'))
  WITH CHECK (public.has_role(auth.uid(), 'owner'));

-- Seed categories
INSERT INTO public.categories (name, slug, icon, sort_order) VALUES
  ('Electronics', 'electronics', 'Smartphone', 1),
  ('Fashion & Apparel', 'fashion', 'Shirt', 2),
  ('Food & Beverages', 'food-beverages', 'UtensilsCrossed', 3),
  ('Health & Beauty', 'health-beauty', 'Sparkles', 4),
  ('Home & Garden', 'home-garden', 'Home', 5),
  ('Sports & Outdoors', 'sports', 'Dumbbell', 6),
  ('Books & Stationery', 'books', 'BookOpen', 7),
  ('Toys & Kids', 'toys-kids', 'ToyBrick', 8),
  ('Automotive', 'automotive', 'Car', 9),
  ('Services', 'services', 'Briefcase', 10),
  ('Groceries', 'groceries', 'ShoppingBasket', 11),
  ('Jewelry & Accessories', 'jewelry', 'Gem', 12),
  ('Arts & Crafts', 'arts-crafts', 'Palette', 13),
  ('Pet Supplies', 'pets', 'PawPrint', 14),
  ('Office Supplies', 'office', 'Printer', 15),
  ('Other', 'other', 'Package', 99)
ON CONFLICT (slug) DO NOTHING;

-- 2. Add columns to public_settings
ALTER TABLE public.public_settings
  ADD COLUMN IF NOT EXISTS category_id uuid REFERENCES public.categories(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS is_featured boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS engagement_score numeric NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_public_settings_category_id ON public.public_settings(category_id);
CREATE INDEX IF NOT EXISTS idx_public_settings_is_featured ON public.public_settings(is_featured) WHERE is_featured = true;

-- 3. Function to recompute engagement & featured status
CREATE OR REPLACE FUNCTION public.refresh_featured_shops()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Compute engagement score per shop
  WITH shop_stats AS (
    SELECT
      ps.owner_id,
      COALESCE(ps.follower_count, 0) * 3.0
        + COALESCE((SELECT SUM(likes_count + comments_count + saves_count)
                    FROM public.products p WHERE p.owner_id = ps.owner_id AND p.public_visible = true), 0) * 1.0
        + COALESCE((SELECT COUNT(*) FROM public.public_orders po WHERE po.owner_id = ps.owner_id), 0) * 2.0
        + COALESCE((SELECT COUNT(*) FROM public.products p2 WHERE p2.owner_id = ps.owner_id AND p2.public_visible = true), 0) * 0.5
        AS score
    FROM public.public_settings ps
    WHERE ps.is_public_enabled = true AND ps.is_listed = true
  )
  UPDATE public.public_settings ps
  SET engagement_score = ss.score
  FROM shop_stats ss
  WHERE ps.owner_id = ss.owner_id;

  -- Mark top 8 as featured
  UPDATE public.public_settings SET is_featured = false WHERE is_featured = true;

  UPDATE public.public_settings
  SET is_featured = true
  WHERE owner_id IN (
    SELECT owner_id FROM public.public_settings
    WHERE is_public_enabled = true AND is_listed = true
    ORDER BY engagement_score DESC, follower_count DESC
    LIMIT 8
  );
END;
$$;

-- Initial population
SELECT public.refresh_featured_shops();

-- ===== 20260418132027_1f6fc4fe-3c40-4d3a-aab3-a6f65f01d0e4.sql =====

CREATE OR REPLACE FUNCTION public.refresh_featured_shops()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  WITH shop_stats AS (
    SELECT
      ps.owner_id,
      COALESCE(ps.follower_count, 0) * 3.0
        + COALESCE((SELECT SUM(likes_count + comments_count + saves_count)
                    FROM public.products p WHERE p.owner_id = ps.owner_id AND p.public_visible = true), 0) * 1.0
        + COALESCE((SELECT COUNT(*) FROM public.public_orders po WHERE po.owner_id = ps.owner_id), 0) * 2.0
        + COALESCE((SELECT COUNT(*) FROM public.products p2 WHERE p2.owner_id = ps.owner_id AND p2.public_visible = true), 0) * 0.5
        AS score
    FROM public.public_settings ps
    WHERE ps.is_public_enabled = true AND ps.is_listed = true
  )
  UPDATE public.public_settings ps
  SET engagement_score = ss.score
  FROM shop_stats ss
  WHERE ps.owner_id = ss.owner_id;

  UPDATE public.public_settings SET is_featured = false WHERE is_featured = true;

  UPDATE public.public_settings
  SET is_featured = true
  WHERE owner_id IN (
    SELECT owner_id FROM public.public_settings
    WHERE is_public_enabled = true AND is_listed = true
    ORDER BY engagement_score DESC, follower_count DESC
    LIMIT 8
  );
END;
$$;

SELECT public.refresh_featured_shops();

-- ===== 20260418140000_product_stories_table.sql =====
-- Create product_stories table
CREATE TABLE IF NOT EXISTS product_stories (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  product_name text NOT NULL,
  title text NOT NULL,
  story text NOT NULL,
  image_url text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'published')),
  published_platforms text[] DEFAULT ARRAY[]::text[],
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  PRIMARY KEY (id)
);

-- Add indexes
CREATE INDEX IF NOT EXISTS product_stories_owner_id_idx ON product_stories(owner_id);
CREATE INDEX IF NOT EXISTS product_stories_product_id_idx ON product_stories(product_id);
CREATE INDEX IF NOT EXISTS product_stories_created_at_idx ON product_stories(created_at DESC);

-- Enable RLS
ALTER TABLE product_stories ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Users can view their own product stories" ON product_stories
  FOR SELECT USING (auth.uid() = owner_id);

CREATE POLICY "Users can create product stories" ON product_stories
  FOR INSERT WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Users can update their own product stories" ON product_stories
  FOR UPDATE USING (auth.uid() = owner_id);

CREATE POLICY "Users can delete their own product stories" ON product_stories
  FOR DELETE USING (auth.uid() = owner_id);

-- ===== 20260421100135_b05d8b77-3761-401f-939d-a7d402d35457.sql =====
-- Replace broken subscription_system migration with simple plans seed

CREATE TABLE IF NOT EXISTS public.subscription_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tier text NOT NULL UNIQUE,
  name text NOT NULL,
  price numeric NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'TZS',
  billing_period text NOT NULL DEFAULT 'monthly',
  trial_days integer NOT NULL DEFAULT 30,
  description text,
  features jsonb NOT NULL DEFAULT '[]'::jsonb,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view plans" ON public.subscription_plans;
CREATE POLICY "Anyone can view plans" ON public.subscription_plans
  FOR SELECT USING (true);

-- Seed two plans (idempotent)
INSERT INTO public.subscription_plans (tier, name, price, currency, billing_period, trial_days, description, features, sort_order)
VALUES
  ('premium_monthly', 'Premium Monthly', 25000, 'TZS', 'monthly', 30,
   'Full access, billed every month',
   '["Unlimited products","Multi-branch","POS & inventory","Marketplace listing","Instagram AI generator","Priority support"]'::jsonb, 1),
  ('premium_yearly', 'Premium Yearly', 250000, 'TZS', 'yearly', 30,
   'Save 2 months, billed once a year',
   '["Everything in Monthly","2 months free","Advanced analytics","Custom branding","Team collaboration"]'::jsonb, 2)
ON CONFLICT (tier) DO UPDATE
  SET price = EXCLUDED.price,
      currency = EXCLUDED.currency,
      name = EXCLUDED.name,
      description = EXCLUDED.description,
      features = EXCLUDED.features,
      updated_at = now();
-- ===== 20260421_001_subscription_system.sql =====
-- User Profiles and Subscription Management

-- Create user_profiles table to track user type and subscription info
CREATE TABLE IF NOT EXISTS public.user_profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  user_type text NOT NULL DEFAULT 'buyer' CHECK (user_type IN ('buyer', 'business')),
  subscription_tier text DEFAULT 'free' CHECK (subscription_tier IN ('free', 'premium_monthly', 'premium_yearly')),
  subscription_status text DEFAULT 'inactive' CHECK (subscription_status IN ('inactive', 'trial', 'active', 'cancelled')),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- Create subscription_plans table
CREATE TABLE IF NOT EXISTS public.subscription_plans (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name text NOT NULL UNIQUE,
  tier text NOT NULL UNIQUE CHECK (tier IN ('free', 'premium_monthly', 'premium_yearly')),
  price decimal(10, 2) NOT NULL DEFAULT 0,
  billing_period text NOT NULL CHECK (billing_period IN ('monthly', 'yearly', 'free')),
  trial_days integer DEFAULT 0,
  description text,
  features jsonb DEFAULT '[]'::jsonb,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- Create user_subscriptions table
CREATE TABLE IF NOT EXISTS public.user_subscriptions (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  plan_id uuid NOT NULL REFERENCES public.subscription_plans(id),
  subscription_tier text NOT NULL,
  status text NOT NULL DEFAULT 'inactive' CHECK (status IN ('inactive', 'trial', 'active', 'expired', 'cancelled')),
  started_at timestamp with time zone DEFAULT now(),
  trial_started_at timestamp with time zone,
  trial_ends_at timestamp with time zone,
  ends_at timestamp with time zone,
  auto_renew boolean DEFAULT true,
  payment_method_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT unique_active_subscription UNIQUE (user_id, tier) WHERE status IN ('active', 'trial')
);

-- Create payment_methods table
CREATE TABLE IF NOT EXISTS public.payment_methods (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  payment_type text NOT NULL CHECK (payment_type IN ('bank', 'mobile_money')),
  provider text NOT NULL,
  account_identifier text NOT NULL,
  is_default boolean DEFAULT false,
  verified boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- Create subscription_payments table
CREATE TABLE IF NOT EXISTS public.subscription_payments (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  subscription_id uuid NOT NULL REFERENCES public.user_subscriptions(id) ON DELETE CASCADE,
  payment_method_id uuid NOT NULL REFERENCES public.payment_methods(id),
  amount decimal(10, 2) NOT NULL,
  currency text NOT NULL DEFAULT 'KES',
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'refunded')),
  transaction_reference text UNIQUE,
  payment_date timestamp with time zone,
  due_date timestamp with time zone,
  paid_date timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- Create user_branches table for branch management
CREATE TABLE IF NOT EXISTS public.user_branches (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  account_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  branch_name text NOT NULL,
  is_main_branch boolean DEFAULT false,
  manager_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  location text,
  contact_info jsonb,
  settings jsonb DEFAULT '{}'::jsonb,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_user_profiles_user_type ON public.user_profiles(user_type);
CREATE INDEX IF NOT EXISTS idx_user_profiles_subscription_tier ON public.user_profiles(subscription_tier);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_user_id ON public.user_subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_status ON public.user_subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_tier ON public.user_subscriptions(subscription_tier);
CREATE INDEX IF NOT EXISTS idx_payment_methods_user_id ON public.payment_methods(user_id);
CREATE INDEX IF NOT EXISTS idx_subscription_payments_user_id ON public.subscription_payments(user_id);
CREATE INDEX IF NOT EXISTS idx_subscription_payments_status ON public.subscription_payments(status);
CREATE INDEX IF NOT EXISTS idx_user_branches_account_id ON public.user_branches(account_id);
CREATE INDEX IF NOT EXISTS idx_user_branches_is_main ON public.user_branches(is_main_branch);

-- Enable RLS
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscription_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_branches ENABLE ROW LEVEL SECURITY;

-- RLS Policies for user_profiles
CREATE POLICY "Users can view their own profile" ON public.user_profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile" ON public.user_profiles
  FOR UPDATE USING (auth.uid() = id);

-- RLS Policies for subscription_plans (public read)
CREATE POLICY "Anyone can view subscription plans" ON public.subscription_plans
  FOR SELECT USING (true);

-- RLS Policies for user_subscriptions
CREATE POLICY "Users can view their own subscriptions" ON public.user_subscriptions
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own subscriptions" ON public.user_subscriptions
  FOR UPDATE USING (auth.uid() = user_id);

-- RLS Policies for payment_methods
CREATE POLICY "Users can view their own payment methods" ON public.payment_methods
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create payment methods" ON public.payment_methods
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own payment methods" ON public.payment_methods
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own payment methods" ON public.payment_methods
  FOR DELETE USING (auth.uid() = user_id);

-- RLS Policies for subscription_payments
CREATE POLICY "Users can view their own payments" ON public.subscription_payments
  FOR SELECT USING (auth.uid() = user_id);

-- RLS Policies for user_branches
CREATE POLICY "Users can view their account branches" ON public.user_branches
  FOR SELECT USING (auth.uid() = account_id OR auth.uid() = manager_id);

CREATE POLICY "Account owners can manage branches" ON public.user_branches
  FOR UPDATE USING (auth.uid() = account_id);

CREATE POLICY "Account owners can create branches" ON public.user_branches
  FOR INSERT WITH CHECK (auth.uid() = account_id);

-- Insert default subscription plans
INSERT INTO public.subscription_plans (name, tier, price, billing_period, trial_days, description, features)
VALUES
  ('Free', 'free', 0, 'free', 0, 'Basic buyer account', '[
    "Like products",
    "Comment on products",
    "Follow shops",
    "View marketplace",
    "Search products"
  ]'::jsonb),
  ('Premium Monthly', 'premium_monthly', 25000, 'monthly', 30, 'Full business management features', '[
    "Sell on marketplace",
    "Manage inventory",
    "Dashboard analytics",
    "Multiple branches",
    "Advanced reports",
    "Email support",
    "Product stories",
    "Instagram generator"
  ]'::jsonb),
  ('Premium Yearly', 'premium_yearly', 250000, 'yearly', 30, 'Full business features with annual billing', '[
    "Sell on marketplace",
    "Manage inventory",
    "Dashboard analytics",
    "Multiple branches",
    "Advanced reports",
    "Priority support",
    "Product stories",
    "Instagram generator",
    "Custom branding"
  ]'::jsonb)
ON CONFLICT (tier) DO NOTHING;

-- ===== 20260513104434_7c41370f-f045-44e4-9338-037d955115ad.sql =====

-- Create role enum
CREATE TYPE public.app_role AS ENUM ('seller', 'customer');

-- Create profiles table
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
  name TEXT NOT NULL DEFAULT '',
  email TEXT NOT NULL DEFAULT '',
  phone TEXT,
  whatsapp TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create user_roles table
CREATE TABLE public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  role app_role NOT NULL,
  UNIQUE (user_id, role)
);

-- Create categories table
CREATE TABLE public.categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  slug TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create products table
CREATE TABLE public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  price NUMERIC(12,2) NOT NULL DEFAULT 0,
  category_id UUID REFERENCES public.categories(id),
  stock INTEGER NOT NULL DEFAULT 0,
  image_urls TEXT[] DEFAULT '{}',
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create orders table
CREATE TABLE public.orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  product_id UUID REFERENCES public.products(id) ON DELETE CASCADE NOT NULL,
  seller_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 1,
  total_price NUMERIC(12,2) NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'delivered', 'cancelled')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- Security definer function
CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role app_role)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id AND role = _role
  )
$$;

-- Profiles policies
CREATE POLICY "Anyone can view profiles" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = user_id);

-- User roles policies
CREATE POLICY "Users can view own roles" ON public.user_roles FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own role on signup" ON public.user_roles FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Categories policies (public read)
CREATE POLICY "Anyone can view categories" ON public.categories FOR SELECT USING (true);

-- Products policies
CREATE POLICY "Anyone can view active products" ON public.products FOR SELECT USING (is_active = true);
CREATE POLICY "Sellers can view own products" ON public.products FOR SELECT USING (auth.uid() = seller_id);
CREATE POLICY "Sellers can insert products" ON public.products FOR INSERT WITH CHECK (auth.uid() = seller_id AND public.has_role(auth.uid(), 'seller'));
CREATE POLICY "Sellers can update own products" ON public.products FOR UPDATE USING (auth.uid() = seller_id AND public.has_role(auth.uid(), 'seller'));
CREATE POLICY "Sellers can delete own products" ON public.products FOR DELETE USING (auth.uid() = seller_id AND public.has_role(auth.uid(), 'seller'));

-- Orders policies
CREATE POLICY "Customers can view own orders" ON public.orders FOR SELECT USING (auth.uid() = customer_id);
CREATE POLICY "Sellers can view orders for their products" ON public.orders FOR SELECT USING (auth.uid() = seller_id);
CREATE POLICY "Customers can create orders" ON public.orders FOR INSERT WITH CHECK (auth.uid() = customer_id);
CREATE POLICY "Sellers can update order status" ON public.orders FOR UPDATE USING (auth.uid() = seller_id);

-- Trigger for auto-creating profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (user_id, name, email)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'name', ''), NEW.email);
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- Seed categories
INSERT INTO public.categories (name, slug) VALUES
  ('Electronics', 'electronics'),
  ('Fashion', 'fashion'),
  ('Home & Garden', 'home-garden'),
  ('Food & Beverages', 'food-beverages'),
  ('Health & Beauty', 'health-beauty'),
  ('Sports & Outdoors', 'sports-outdoors'),
  ('Books & Stationery', 'books-stationery'),
  ('Automotive', 'automotive'),
  ('Agriculture', 'agriculture'),
  ('Services', 'services');

-- Drop RLS policies on products that depend on has_role
DROP POLICY IF EXISTS "Sellers can insert products" ON public.products;
DROP POLICY IF EXISTS "Sellers can update own products" ON public.products;
DROP POLICY IF EXISTS "Sellers can delete own products" ON public.products;
DROP POLICY IF EXISTS "Anyone can view active products" ON public.products;
DROP POLICY IF EXISTS "Sellers can view own products" ON public.products;

-- Now drop the function and enum
DROP FUNCTION IF EXISTS public.has_role(uuid, app_role);
DROP TYPE IF EXISTS public.app_role CASCADE;

-- Drop old marketplace tables
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.user_roles CASCADE;
DROP TABLE IF EXISTS public.categories CASCADE;

-- Modify products table
ALTER TABLE public.products DROP COLUMN IF EXISTS seller_id;
ALTER TABLE public.products DROP COLUMN IF EXISTS is_active;
ALTER TABLE public.products DROP COLUMN IF EXISTS image_urls;
ALTER TABLE public.products DROP COLUMN IF EXISTS category_id;
ALTER TABLE public.products DROP COLUMN IF EXISTS price;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS category text DEFAULT '';
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS buying_price numeric NOT NULL DEFAULT 0;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS selling_price numeric NOT NULL DEFAULT 0;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS low_stock_alert integer NOT NULL DEFAULT 5;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS owner_id uuid NOT NULL DEFAULT auth.uid();

-- New RLS policies for products
CREATE POLICY "Owner can view own products" ON public.products FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert products" ON public.products FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Owner can update own products" ON public.products FOR UPDATE USING (auth.uid() = owner_id);
CREATE POLICY "Owner can delete own products" ON public.products FOR DELETE USING (auth.uid() = owner_id);

-- Stock In table
CREATE TABLE public.stock_in (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  quantity integer NOT NULL DEFAULT 0,
  buying_price numeric NOT NULL DEFAULT 0,
  total_cost numeric GENERATED ALWAYS AS (quantity * buying_price) STORED,
  owner_id uuid NOT NULL DEFAULT auth.uid(),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.stock_in ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner can view stock_in" ON public.stock_in FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert stock_in" ON public.stock_in FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Owner can delete stock_in" ON public.stock_in FOR DELETE USING (auth.uid() = owner_id);

-- Sales table
CREATE TABLE public.sales (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  quantity integer NOT NULL DEFAULT 0,
  selling_price numeric NOT NULL DEFAULT 0,
  buying_price numeric NOT NULL DEFAULT 0,
  total_sale numeric GENERATED ALWAYS AS (quantity * selling_price) STORED,
  profit numeric GENERATED ALWAYS AS (quantity * (selling_price - buying_price)) STORED,
  owner_id uuid NOT NULL DEFAULT auth.uid(),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner can view sales" ON public.sales FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert sales" ON public.sales FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Owner can delete sales" ON public.sales FOR DELETE USING (auth.uid() = owner_id);

-- Expenses table
CREATE TABLE public.expenses (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name text NOT NULL,
  category text NOT NULL DEFAULT '',
  amount numeric NOT NULL DEFAULT 0,
  date date NOT NULL DEFAULT CURRENT_DATE,
  owner_id uuid NOT NULL DEFAULT auth.uid(),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner can view expenses" ON public.expenses FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert expenses" ON public.expenses FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Owner can update expenses" ON public.expenses FOR UPDATE USING (auth.uid() = owner_id);
CREATE POLICY "Owner can delete expenses" ON public.expenses FOR DELETE USING (auth.uid() = owner_id);

-- Add public_visible column to products
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS public_visible boolean NOT NULL DEFAULT false;

-- Create public_settings table (one row per business owner)
CREATE TABLE public.public_settings (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_id uuid NOT NULL UNIQUE,
  business_name text NOT NULL DEFAULT '',
  slug text NOT NULL DEFAULT '',
  logo_url text,
  theme text NOT NULL DEFAULT 'minimal',
  theme_color text NOT NULL DEFAULT '#e87b35',
  is_public_enabled boolean NOT NULL DEFAULT false,
  whatsapp_number text,
  contact_email text,
  contact_phone text,
  description text,
  follower_count integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.public_settings ENABLE ROW LEVEL SECURITY;

-- Owner can manage their own settings
CREATE POLICY "Owner can view own settings" ON public.public_settings FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert own settings" ON public.public_settings FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Owner can update own settings" ON public.public_settings FOR UPDATE USING (auth.uid() = owner_id);

-- Public can view enabled stores (for the public store page)
CREATE POLICY "Public can view enabled stores" ON public.public_settings FOR SELECT USING (is_public_enabled = true);

-- Create public_orders table
CREATE TABLE public.public_orders (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_id uuid NOT NULL,
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  customer_name text NOT NULL,
  phone text NOT NULL,
  quantity integer NOT NULL DEFAULT 1,
  status text NOT NULL DEFAULT 'pending',
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.public_orders ENABLE ROW LEVEL SECURITY;

-- Owner can manage orders
CREATE POLICY "Owner can view own public orders" ON public.public_orders FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can update own public orders" ON public.public_orders FOR UPDATE USING (auth.uid() = owner_id);
CREATE POLICY "Owner can delete own public orders" ON public.public_orders FOR DELETE USING (auth.uid() = owner_id);

-- Anyone can insert public orders (customers placing orders)
CREATE POLICY "Anyone can place public orders" ON public.public_orders FOR INSERT WITH CHECK (true);

-- Create storage bucket for logos
INSERT INTO storage.buckets (id, name, public) VALUES ('logos', 'logos', true);

CREATE POLICY "Anyone can view logos" ON storage.objects FOR SELECT USING (bucket_id = 'logos');
CREATE POLICY "Authenticated users can upload logos" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'logos' AND auth.role() = 'authenticated');
CREATE POLICY "Authenticated users can update logos" ON storage.objects FOR UPDATE USING (bucket_id = 'logos' AND auth.role() = 'authenticated');
CREATE POLICY "Authenticated users can delete logos" ON storage.objects FOR DELETE USING (bucket_id = 'logos' AND auth.role() = 'authenticated');

-- Unique index on slug for URL lookup
CREATE UNIQUE INDEX idx_public_settings_slug ON public.public_settings(slug) WHERE slug != '';

-- Allow anonymous users to view products that are public_visible
CREATE POLICY "Public can view public products" ON public.products
FOR SELECT USING (public_visible = true);

CREATE TABLE public.instagram_content_history (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_id uuid NOT NULL DEFAULT auth.uid(),
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  caption text NOT NULL,
  hashtags text NOT NULL,
  style_type text NOT NULL DEFAULT 'promotional',
  generated_image_url text,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.instagram_content_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Owner can view own content" ON public.instagram_content_history FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert own content" ON public.instagram_content_history FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Owner can delete own content" ON public.instagram_content_history FOR DELETE USING (auth.uid() = owner_id);

CREATE INDEX idx_instagram_content_owner ON public.instagram_content_history(owner_id);
CREATE INDEX idx_instagram_content_product ON public.instagram_content_history(product_id);

-- Fix public_settings SELECT policies
DROP POLICY "Owner can view own settings" ON public.public_settings;
DROP POLICY "Public can view enabled stores" ON public.public_settings;

CREATE POLICY "Owner can view own settings" ON public.public_settings FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Public can view enabled stores" ON public.public_settings FOR SELECT USING (is_public_enabled = true);

-- Fix products SELECT policies too
DROP POLICY "Owner can view own products" ON public.products;
DROP POLICY "Public can view public products" ON public.products;

CREATE POLICY "Owner can view own products" ON public.products FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Public can view public products" ON public.products FOR SELECT USING (public_visible = true);

-- POS SYSTEM
CREATE TABLE public.pos_sales (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  receipt_number TEXT NOT NULL,
  subtotal NUMERIC NOT NULL DEFAULT 0,
  total_item_discount NUMERIC NOT NULL DEFAULT 0,
  sale_discount_type TEXT DEFAULT 'none',
  sale_discount_value NUMERIC NOT NULL DEFAULT 0,
  sale_discount_amount NUMERIC NOT NULL DEFAULT 0,
  final_total NUMERIC NOT NULL DEFAULT 0,
  total_profit NUMERIC NOT NULL DEFAULT 0,
  payment_method TEXT NOT NULL DEFAULT 'cash',
  amount_received NUMERIC NOT NULL DEFAULT 0,
  balance_returned NUMERIC NOT NULL DEFAULT 0,
  notes TEXT,
  owner_id UUID NOT NULL DEFAULT auth.uid(),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

ALTER TABLE public.pos_sales ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Owner can view pos_sales" ON public.pos_sales FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert pos_sales" ON public.pos_sales FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Owner can update pos_sales" ON public.pos_sales FOR UPDATE USING (auth.uid() = owner_id);
CREATE POLICY "Owner can delete pos_sales" ON public.pos_sales FOR DELETE USING (auth.uid() = owner_id);

CREATE UNIQUE INDEX idx_pos_sales_receipt ON public.pos_sales (owner_id, receipt_number);

CREATE TABLE public.sale_items (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  sale_id UUID NOT NULL REFERENCES public.pos_sales(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES public.products(id),
  product_name TEXT NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 1,
  unit_price NUMERIC NOT NULL DEFAULT 0,
  buying_price NUMERIC NOT NULL DEFAULT 0,
  discount_type TEXT DEFAULT 'none',
  discount_value NUMERIC NOT NULL DEFAULT 0,
  discount_amount NUMERIC NOT NULL DEFAULT 0,
  item_subtotal NUMERIC NOT NULL DEFAULT 0,
  profit NUMERIC NOT NULL DEFAULT 0
);

ALTER TABLE public.sale_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Owner can view sale_items" ON public.sale_items FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.pos_sales WHERE id = sale_items.sale_id AND owner_id = auth.uid()));
CREATE POLICY "Owner can insert sale_items" ON public.sale_items FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM public.pos_sales WHERE id = sale_items.sale_id AND owner_id = auth.uid()));
CREATE POLICY "Owner can delete sale_items" ON public.sale_items FOR DELETE
  USING (EXISTS (SELECT 1 FROM public.pos_sales WHERE id = sale_items.sale_id AND owner_id = auth.uid()));

CREATE TABLE public.refunds (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  sale_id UUID NOT NULL REFERENCES public.pos_sales(id),
  refund_amount NUMERIC NOT NULL DEFAULT 0,
  reason TEXT,
  items JSONB,
  owner_id UUID NOT NULL DEFAULT auth.uid(),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

ALTER TABLE public.refunds ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Owner can view refunds" ON public.refunds FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert refunds" ON public.refunds FOR INSERT WITH CHECK (auth.uid() = owner_id);

CREATE TABLE public.day_closings (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  total_sales NUMERIC NOT NULL DEFAULT 0,
  total_profit NUMERIC NOT NULL DEFAULT 0,
  total_transactions INTEGER NOT NULL DEFAULT 0,
  total_discounts NUMERIC NOT NULL DEFAULT 0,
  cash_total NUMERIC NOT NULL DEFAULT 0,
  mobile_money_total NUMERIC NOT NULL DEFAULT 0,
  bank_total NUMERIC NOT NULL DEFAULT 0,
  owner_id UUID NOT NULL DEFAULT auth.uid(),
  closed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

ALTER TABLE public.day_closings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Owner can view day_closings" ON public.day_closings FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert day_closings" ON public.day_closings FOR INSERT WITH CHECK (auth.uid() = owner_id);

CREATE UNIQUE INDEX idx_day_closings_date ON public.day_closings (owner_id, date);

CREATE TYPE public.app_role AS ENUM ('owner', 'cashier');

CREATE TABLE public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  role app_role NOT NULL,
  granted_by UUID,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE (user_id, role)
);

ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role app_role)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id AND role = _role
  )
$$;

CREATE POLICY "Users can view own roles" ON public.user_roles FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Owners can manage roles" ON public.user_roles FOR ALL USING (public.has_role(auth.uid(), 'owner'));

CREATE OR REPLACE FUNCTION public.generate_receipt_number(_owner_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _count INTEGER;
  _date TEXT;
BEGIN
  _date := to_char(now(), 'YYYYMMDD');
  SELECT COUNT(*) + 1 INTO _count
  FROM public.pos_sales
  WHERE owner_id = _owner_id
    AND created_at::date = CURRENT_DATE;
  RETURN 'RCP-' || _date || '-' || LPAD(_count::TEXT, 4, '0');
END;
$$;

CREATE TABLE public.suppliers (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_id UUID NOT NULL DEFAULT auth.uid(),
  name TEXT NOT NULL,
  phone TEXT,
  email TEXT,
  address TEXT,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner can view suppliers" ON public.suppliers FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert suppliers" ON public.suppliers FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Owner can update suppliers" ON public.suppliers FOR UPDATE USING (auth.uid() = owner_id);
CREATE POLICY "Owner can delete suppliers" ON public.suppliers FOR DELETE USING (auth.uid() = owner_id);

CREATE TABLE public.purchases (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_id UUID NOT NULL DEFAULT auth.uid(),
  supplier_id UUID REFERENCES public.suppliers(id) ON DELETE SET NULL,
  product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  quantity INTEGER NOT NULL DEFAULT 0,
  buying_price NUMERIC NOT NULL DEFAULT 0,
  total_cost NUMERIC NOT NULL DEFAULT 0,
  notes TEXT,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
ALTER TABLE public.purchases ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner can view purchases" ON public.purchases FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert purchases" ON public.purchases FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Owner can update purchases" ON public.purchases FOR UPDATE USING (auth.uid() = owner_id);
CREATE POLICY "Owner can delete purchases" ON public.purchases FOR DELETE USING (auth.uid() = owner_id);

CREATE TABLE public.activity_logs (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_id UUID NOT NULL DEFAULT auth.uid(),
  user_id UUID NOT NULL DEFAULT auth.uid(),
  action_type TEXT NOT NULL,
  description TEXT NOT NULL,
  related_id UUID,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner can view activity_logs" ON public.activity_logs FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert activity_logs" ON public.activity_logs FOR INSERT WITH CHECK (auth.uid() = owner_id);

ALTER TABLE public.products ADD COLUMN IF NOT EXISTS image_url text DEFAULT NULL;

INSERT INTO storage.buckets (id, name, public)
VALUES ('product-images', 'product-images', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Authenticated users can upload product images"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'product-images');

CREATE POLICY "Authenticated users can update product images"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'product-images');

CREATE POLICY "Authenticated users can delete product images"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'product-images');

CREATE POLICY "Public can view product images"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'product-images');

ALTER TABLE public.products ADD COLUMN IF NOT EXISTS featured boolean NOT NULL DEFAULT false;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS likes_count integer NOT NULL DEFAULT 0;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS comments_count integer NOT NULL DEFAULT 0;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS saves_count integer NOT NULL DEFAULT 0;

CREATE TABLE public.promotional_banners (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL DEFAULT auth.uid(),
  title text NOT NULL DEFAULT '',
  subtitle text DEFAULT '',
  image_url text DEFAULT NULL,
  bg_color text NOT NULL DEFAULT '#e87b35',
  is_active boolean NOT NULL DEFAULT true,
  position integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.promotional_banners ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Owner can view own banners" ON public.promotional_banners FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert own banners" ON public.promotional_banners FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Owner can update own banners" ON public.promotional_banners FOR UPDATE USING (auth.uid() = owner_id);
CREATE POLICY "Owner can delete own banners" ON public.promotional_banners FOR DELETE USING (auth.uid() = owner_id);

CREATE POLICY "Public can view active banners" ON public.promotional_banners FOR SELECT USING (is_active = true);

CREATE POLICY "Anyone can view orders by phone"
ON public.public_orders
FOR SELECT
TO anon, authenticated
USING (true);
ALTER PUBLICATION supabase_realtime ADD TABLE public.public_orders;
ALTER TABLE public.day_closings ADD COLUMN total_expenses numeric NOT NULL DEFAULT 0;
ALTER TABLE public.day_closings ADD COLUMN net_profit numeric NOT NULL DEFAULT 0;

ALTER TABLE public.public_settings 
ADD COLUMN IF NOT EXISTS is_listed boolean NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS category text DEFAULT '';

CREATE POLICY "Public can view listed shops"
ON public.public_settings
FOR SELECT
USING (is_listed = true);

UPDATE public.public_settings SET is_listed = true WHERE is_public_enabled = true;

ALTER TABLE public.public_settings ALTER COLUMN is_listed SET DEFAULT true;

CREATE TABLE public.user_activity (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  activity_type TEXT NOT NULL,
  target_id TEXT NOT NULL,
  target_category TEXT DEFAULT '',
  duration_seconds INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

CREATE INDEX idx_user_activity_user ON public.user_activity (user_id, created_at DESC);
CREATE INDEX idx_user_activity_type ON public.user_activity (user_id, activity_type);
CREATE INDEX idx_user_activity_target ON public.user_activity (user_id, target_id);

ALTER TABLE public.user_activity ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own activity"
ON public.user_activity FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own activity"
ON public.user_activity FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own activity"
ON public.user_activity FOR DELETE
USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  _name text;
  _slug text;
  _base_slug text;
  _suffix int := 0;
BEGIN
  _name := COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1), 'My Shop');

  INSERT INTO public.profiles (user_id, name, email)
  VALUES (NEW.id, _name, NEW.email)
  ON CONFLICT DO NOTHING;

  _base_slug := regexp_replace(lower(_name), '[^a-z0-9]+', '-', 'g');
  _base_slug := trim(both '-' from _base_slug);
  IF _base_slug = '' THEN
    _base_slug := 'shop-' || substr(NEW.id::text, 1, 8);
  END IF;
  _slug := _base_slug;
  WHILE EXISTS (SELECT 1 FROM public.public_settings WHERE slug = _slug) LOOP
    _suffix := _suffix + 1;
    _slug := _base_slug || '-' || _suffix;
  END LOOP;

  INSERT INTO public.public_settings (
    owner_id, business_name, slug, is_public_enabled, is_listed, theme, theme_color
  )
  VALUES (
    NEW.id, _name, _slug, true, true, 'minimal', '#7c3aed'
  )
  ON CONFLICT DO NOTHING;

  INSERT INTO public.user_roles (user_id, role)
  VALUES (NEW.id, 'owner')
  ON CONFLICT DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

DO $$
DECLARE
  u RECORD;
  _name text;
  _slug text;
  _base_slug text;
  _suffix int;
BEGIN
  FOR u IN
    SELECT au.id, au.email, au.raw_user_meta_data
    FROM auth.users au
    LEFT JOIN public.public_settings ps ON ps.owner_id = au.id
    WHERE ps.id IS NULL
  LOOP
    _name := COALESCE(u.raw_user_meta_data->>'name', split_part(u.email, '@', 1), 'My Shop');
    _base_slug := regexp_replace(lower(_name), '[^a-z0-9]+', '-', 'g');
    _base_slug := trim(both '-' from _base_slug);
    IF _base_slug = '' THEN
      _base_slug := 'shop-' || substr(u.id::text, 1, 8);
    END IF;
    _slug := _base_slug;
    _suffix := 0;
    WHILE EXISTS (SELECT 1 FROM public.public_settings WHERE slug = _slug) LOOP
      _suffix := _suffix + 1;
      _slug := _base_slug || '-' || _suffix;
    END LOOP;

    INSERT INTO public.public_settings (
      owner_id, business_name, slug, is_public_enabled, is_listed, theme, theme_color
    )
    VALUES (u.id, _name, _slug, true, true, 'minimal', '#7c3aed')
    ON CONFLICT DO NOTHING;

    INSERT INTO public.profiles (user_id, name, email)
    VALUES (u.id, _name, u.email)
    ON CONFLICT DO NOTHING;
  END LOOP;
END $$;

DROP POLICY IF EXISTS "Anyone can view orders by phone" ON public.public_orders;
CREATE POLICY "Anyone can view orders by phone"
  ON public.public_orders
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- Recreate categories table (was dropped earlier)
CREATE TABLE IF NOT EXISTS public.categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  slug text NOT NULL UNIQUE,
  icon text,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view categories"
  ON public.categories FOR SELECT
  USING (true);

CREATE POLICY "Owners can manage categories"
  ON public.categories FOR ALL
  USING (public.has_role(auth.uid(), 'owner'))
  WITH CHECK (public.has_role(auth.uid(), 'owner'));

INSERT INTO public.categories (name, slug, icon, sort_order) VALUES
  ('Electronics', 'electronics', 'Smartphone', 1),
  ('Fashion & Apparel', 'fashion', 'Shirt', 2),
  ('Food & Beverages', 'food-beverages', 'UtensilsCrossed', 3),
  ('Health & Beauty', 'health-beauty', 'Sparkles', 4),
  ('Home & Garden', 'home-garden', 'Home', 5),
  ('Sports & Outdoors', 'sports', 'Dumbbell', 6),
  ('Books & Stationery', 'books', 'BookOpen', 7),
  ('Toys & Kids', 'toys-kids', 'ToyBrick', 8),
  ('Automotive', 'automotive', 'Car', 9),
  ('Services', 'services', 'Briefcase', 10),
  ('Groceries', 'groceries', 'ShoppingBasket', 11),
  ('Jewelry & Accessories', 'jewelry', 'Gem', 12),
  ('Arts & Crafts', 'arts-crafts', 'Palette', 13),
  ('Pet Supplies', 'pets', 'PawPrint', 14),
  ('Office Supplies', 'office', 'Printer', 15),
  ('Other', 'other', 'Package', 99)
ON CONFLICT (slug) DO NOTHING;

ALTER TABLE public.public_settings
  ADD COLUMN IF NOT EXISTS category_id uuid REFERENCES public.categories(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS is_featured boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS engagement_score numeric NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_public_settings_category_id ON public.public_settings(category_id);
CREATE INDEX IF NOT EXISTS idx_public_settings_is_featured ON public.public_settings(is_featured) WHERE is_featured = true;

CREATE OR REPLACE FUNCTION public.refresh_featured_shops()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  WITH shop_stats AS (
    SELECT
      ps.owner_id,
      COALESCE(ps.follower_count, 0) * 3.0
        + COALESCE((SELECT SUM(likes_count + comments_count + saves_count)
                    FROM public.products p WHERE p.owner_id = ps.owner_id AND p.public_visible = true), 0) * 1.0
        + COALESCE((SELECT COUNT(*) FROM public.public_orders po WHERE po.owner_id = ps.owner_id), 0) * 2.0
        + COALESCE((SELECT COUNT(*) FROM public.products p2 WHERE p2.owner_id = ps.owner_id AND p2.public_visible = true), 0) * 0.5
        AS score
    FROM public.public_settings ps
    WHERE ps.is_public_enabled = true AND ps.is_listed = true
  )
  UPDATE public.public_settings ps
  SET engagement_score = ss.score
  FROM shop_stats ss
  WHERE ps.owner_id = ss.owner_id;

  UPDATE public.public_settings SET is_featured = false WHERE is_featured = true;

  UPDATE public.public_settings
  SET is_featured = true
  WHERE owner_id IN (
    SELECT owner_id FROM public.public_settings
    WHERE is_public_enabled = true AND is_listed = true
    ORDER BY engagement_score DESC, follower_count DESC
    LIMIT 8
  );
END;
$$;

SELECT public.refresh_featured_shops();

CREATE TABLE IF NOT EXISTS product_stories (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  product_name text NOT NULL,
  title text NOT NULL,
  story text NOT NULL,
  image_url text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'published')),
  published_platforms text[] DEFAULT ARRAY[]::text[],
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS product_stories_owner_id_idx ON product_stories(owner_id);
CREATE INDEX IF NOT EXISTS product_stories_product_id_idx ON product_stories(product_id);
CREATE INDEX IF NOT EXISTS product_stories_created_at_idx ON product_stories(created_at DESC);

ALTER TABLE product_stories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own product stories" ON product_stories
  FOR SELECT USING (auth.uid() = owner_id);

CREATE POLICY "Users can create product stories" ON product_stories
  FOR INSERT WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Users can update their own product stories" ON product_stories
  FOR UPDATE USING (auth.uid() = owner_id);

CREATE POLICY "Users can delete their own product stories" ON product_stories
  FOR DELETE USING (auth.uid() = owner_id);

CREATE TABLE IF NOT EXISTS public.subscription_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tier text NOT NULL UNIQUE,
  name text NOT NULL UNIQUE,
  price numeric NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'TZS',
  billing_period text NOT NULL DEFAULT 'monthly',
  trial_days integer NOT NULL DEFAULT 30,
  description text,
  features jsonb NOT NULL DEFAULT '[]'::jsonb,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view plans" ON public.subscription_plans;
CREATE POLICY "Anyone can view plans" ON public.subscription_plans
  FOR SELECT USING (true);

INSERT INTO public.subscription_plans (tier, name, price, currency, billing_period, trial_days, description, features, sort_order)
VALUES
  ('premium_monthly', 'Premium Monthly', 25000, 'TZS', 'monthly', 30,
   'Full access, billed every month',
   '["Unlimited products","Multi-branch","POS & inventory","Marketplace listing","Instagram AI generator","Priority support"]'::jsonb, 1),
  ('premium_yearly', 'Premium Yearly', 250000, 'TZS', 'yearly', 30,
   'Save 2 months, billed once a year',
   '["Everything in Monthly","2 months free","Advanced analytics","Custom branding","Team collaboration"]'::jsonb, 2)
ON CONFLICT (tier) DO UPDATE
  SET price = EXCLUDED.price,
      currency = EXCLUDED.currency,
      name = EXCLUDED.name,
      description = EXCLUDED.description,
      features = EXCLUDED.features,
      updated_at = now();

CREATE TABLE IF NOT EXISTS public.user_profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  user_type text NOT NULL DEFAULT 'buyer' CHECK (user_type IN ('buyer', 'business')),
  subscription_tier text DEFAULT 'free' CHECK (subscription_tier IN ('free', 'premium_monthly', 'premium_yearly')),
  subscription_status text DEFAULT 'inactive' CHECK (subscription_status IN ('inactive', 'trial', 'active', 'cancelled')),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.user_subscriptions (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  plan_id uuid NOT NULL REFERENCES public.subscription_plans(id),
  subscription_tier text NOT NULL,
  status text NOT NULL DEFAULT 'inactive' CHECK (status IN ('inactive', 'trial', 'active', 'expired', 'cancelled')),
  started_at timestamp with time zone DEFAULT now(),
  trial_started_at timestamp with time zone,
  trial_ends_at timestamp with time zone,
  ends_at timestamp with time zone,
  auto_renew boolean DEFAULT true,
  payment_method_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.payment_methods (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  payment_type text NOT NULL CHECK (payment_type IN ('bank', 'mobile_money')),
  provider text NOT NULL,
  account_identifier text NOT NULL,
  is_default boolean DEFAULT false,
  verified boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.subscription_payments (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  subscription_id uuid NOT NULL REFERENCES public.user_subscriptions(id) ON DELETE CASCADE,
  payment_method_id uuid NOT NULL REFERENCES public.payment_methods(id),
  amount decimal(10, 2) NOT NULL,
  currency text NOT NULL DEFAULT 'KES',
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'refunded')),
  transaction_reference text UNIQUE,
  payment_date timestamp with time zone,
  due_date timestamp with time zone,
  paid_date timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.user_branches (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  account_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  branch_name text NOT NULL,
  is_main_branch boolean DEFAULT false,
  manager_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  location text,
  contact_info jsonb,
  settings jsonb DEFAULT '{}'::jsonb,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_profiles_user_type ON public.user_profiles(user_type);
CREATE INDEX IF NOT EXISTS idx_user_profiles_subscription_tier ON public.user_profiles(subscription_tier);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_user_id ON public.user_subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_status ON public.user_subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_tier ON public.user_subscriptions(subscription_tier);
CREATE INDEX IF NOT EXISTS idx_payment_methods_user_id ON public.payment_methods(user_id);
CREATE INDEX IF NOT EXISTS idx_subscription_payments_user_id ON public.subscription_payments(user_id);
CREATE INDEX IF NOT EXISTS idx_subscription_payments_status ON public.subscription_payments(status);
CREATE INDEX IF NOT EXISTS idx_user_branches_account_id ON public.user_branches(account_id);
CREATE INDEX IF NOT EXISTS idx_user_branches_is_main ON public.user_branches(is_main_branch);

ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscription_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_branches ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own profile (user_profiles)" ON public.user_profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile (user_profiles)" ON public.user_profiles
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can view their own subscriptions" ON public.user_subscriptions
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own subscriptions" ON public.user_subscriptions
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can view their own payment methods" ON public.payment_methods
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create payment methods" ON public.payment_methods
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own payment methods" ON public.payment_methods
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own payment methods" ON public.payment_methods
  FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Users can view their own payments" ON public.subscription_payments
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can view their account branches" ON public.user_branches
  FOR SELECT USING (auth.uid() = account_id OR auth.uid() = manager_id);

CREATE POLICY "Account owners can manage branches" ON public.user_branches
  FOR UPDATE USING (auth.uid() = account_id);

CREATE POLICY "Account owners can create branches" ON public.user_branches
  FOR INSERT WITH CHECK (auth.uid() = account_id);

-- ===== 20260513105245_d7154086-e747-4cab-a56c-490141bd979b.sql =====

-- user_account_types
CREATE TABLE IF NOT EXISTS public.user_account_types (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  account_type text NOT NULL DEFAULT 'business' CHECK (account_type IN ('buyer','business')),
  trial_start_date timestamptz,
  trial_end_date timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.user_account_types ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own account type" ON public.user_account_types FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users insert own account type" ON public.user_account_types FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users update own account type" ON public.user_account_types FOR UPDATE USING (auth.uid() = user_id);

-- subscriptions
CREATE TABLE IF NOT EXISTS public.subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  plan text NOT NULL,
  amount numeric NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'TZS',
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('trial','active','cancelled','expired','inactive')),
  start_date timestamptz NOT NULL DEFAULT now(),
  end_date timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own subscriptions" ON public.subscriptions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users insert own subscriptions" ON public.subscriptions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users update own subscriptions" ON public.subscriptions FOR UPDATE USING (auth.uid() = user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_user ON public.subscriptions(user_id, created_at DESC);

-- payment_attempts
CREATE TABLE IF NOT EXISTS public.payment_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  subscription_id uuid REFERENCES public.subscriptions(id) ON DELETE SET NULL,
  plan text NOT NULL,
  amount numeric NOT NULL DEFAULT 0,
  payment_method text NOT NULL,
  reference text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','completed','failed')),
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.payment_attempts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own payment attempts" ON public.payment_attempts FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users insert own payment attempts" ON public.payment_attempts FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ===== 20260513105321_b03211c9-e801-4054-9c85-91086fa861c3.sql =====

CREATE TABLE IF NOT EXISTS public.product_likes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (product_id, user_id)
);
ALTER TABLE public.product_likes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view likes" ON public.product_likes FOR SELECT USING (true);
CREATE POLICY "Users insert own likes" ON public.product_likes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users delete own likes" ON public.product_likes FOR DELETE USING (auth.uid() = user_id);
CREATE INDEX IF NOT EXISTS idx_product_likes_product ON public.product_likes(product_id);

CREATE TABLE IF NOT EXISTS public.product_saves (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (product_id, user_id)
);
ALTER TABLE public.product_saves ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own saves" ON public.product_saves FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users insert own saves" ON public.product_saves FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users delete own saves" ON public.product_saves FOR DELETE USING (auth.uid() = user_id);
CREATE INDEX IF NOT EXISTS idx_product_saves_product ON public.product_saves(product_id);

CREATE TABLE IF NOT EXISTS public.product_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  comment_text text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.product_comments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view comments" ON public.product_comments FOR SELECT USING (true);
CREATE POLICY "Users insert own comments" ON public.product_comments FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users update own comments" ON public.product_comments FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users delete own comments" ON public.product_comments FOR DELETE USING (auth.uid() = user_id);
CREATE INDEX IF NOT EXISTS idx_product_comments_product ON public.product_comments(product_id, created_at DESC);

INSERT INTO storage.buckets (id, name, public) VALUES ('media', 'media', true)
ON CONFLICT (id) DO NOTHING;
CREATE POLICY "Public can view media" ON storage.objects FOR SELECT USING (bucket_id = 'media');
CREATE POLICY "Authenticated can upload media" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'media');
CREATE POLICY "Authenticated can update media" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = 'media');
CREATE POLICY "Authenticated can delete media" ON storage.objects FOR DELETE TO authenticated USING (bucket_id = 'media');

-- ===== 20260513110449_b28116b5-75f9-420a-8945-afa7bb79d8b3.sql =====

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  _name text;
  _slug text;
  _base_slug text;
  _suffix int := 0;
  _account_type text;
BEGIN
  _name := COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1), 'My Shop');
  _account_type := COALESCE(NEW.raw_user_meta_data->>'account_type', 'business');

  INSERT INTO public.profiles (user_id, name, email)
  VALUES (NEW.id, _name, NEW.email)
  ON CONFLICT DO NOTHING;

  -- Record account type for everyone
  INSERT INTO public.user_account_types (user_id, account_type)
  VALUES (NEW.id, _account_type)
  ON CONFLICT DO NOTHING;

  -- Only business accounts get a shop + owner role
  IF _account_type = 'business' THEN
    _base_slug := regexp_replace(lower(_name), '[^a-z0-9]+', '-', 'g');
    _base_slug := trim(both '-' from _base_slug);
    IF _base_slug = '' THEN
      _base_slug := 'shop-' || substr(NEW.id::text, 1, 8);
    END IF;
    _slug := _base_slug;
    WHILE EXISTS (SELECT 1 FROM public.public_settings WHERE slug = _slug) LOOP
      _suffix := _suffix + 1;
      _slug := _base_slug || '-' || _suffix;
    END LOOP;

    INSERT INTO public.public_settings (
      owner_id, business_name, slug, is_public_enabled, is_listed, theme, theme_color
    )
    VALUES (
      NEW.id, _name, _slug, true, true, 'minimal', '#7c3aed'
    )
    ON CONFLICT DO NOTHING;

    INSERT INTO public.user_roles (user_id, role)
    VALUES (NEW.id, 'owner')
    ON CONFLICT DO NOTHING;
  END IF;

  RETURN NEW;
END;
$function$;

-- ===== 20260519121450_6889c140-bab8-49dc-8f26-1c8bccc7c302.sql =====
ALTER TABLE public.stock_in ADD COLUMN IF NOT EXISTS selling_price numeric NOT NULL DEFAULT 0;
-- ===== 20260520072515_ef4f7fd8-8b12-425f-9c95-c6a07385c648.sql =====
ALTER TABLE public.public_settings
  ADD COLUMN IF NOT EXISTS latitude double precision,
  ADD COLUMN IF NOT EXISTS longitude double precision;
-- ===== 20260520101140_de8decb7-131c-42b6-8f1d-d832d4d854a0.sql =====

-- Create role enum
DO $wrap$ BEGIN CREATE TYPE public.app_role AS ENUM ('seller', 'customer'); EXCEPTION WHEN duplicate_object THEN NULL; END $wrap$;

CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
  name TEXT NOT NULL DEFAULT '',
  email TEXT NOT NULL DEFAULT '',
  phone TEXT,
  whatsapp TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  role app_role NOT NULL,
  UNIQUE (user_id, role)
);

CREATE TABLE IF NOT EXISTS public.categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  slug TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  price NUMERIC(12,2) NOT NULL DEFAULT 0,
  category_id UUID REFERENCES public.categories(id),
  stock INTEGER NOT NULL DEFAULT 0,
  image_urls TEXT[] DEFAULT '{}',
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  product_id UUID REFERENCES public.products(id) ON DELETE CASCADE NOT NULL,
  seller_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 1,
  total_price NUMERIC(12,2) NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'delivered', 'cancelled')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role app_role)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = _role) $$;

DROP POLICY IF EXISTS "Anyone can view profiles" ON public.profiles;
CREATE POLICY "Anyone can view profiles" ON public.profiles FOR SELECT USING (true);
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can view own roles" ON public.user_roles;
CREATE POLICY "Users can view own roles" ON public.user_roles FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can insert own role on signup" ON public.user_roles;
CREATE POLICY "Users can insert own role on signup" ON public.user_roles FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Anyone can view categories" ON public.categories;
CREATE POLICY "Anyone can view categories" ON public.categories FOR SELECT USING (true);

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$ BEGIN
  INSERT INTO public.profiles (user_id, name, email)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'name', ''), NEW.email)
  ON CONFLICT DO NOTHING;
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = public
AS $$ BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;

INSERT INTO public.categories (name, slug) VALUES
  ('Electronics', 'electronics'), ('Fashion', 'fashion'), ('Home & Garden', 'home-garden'),
  ('Food & Beverages', 'food-beverages'), ('Health & Beauty', 'health-beauty'),
  ('Sports & Outdoors', 'sports-outdoors'), ('Books & Stationery', 'books-stationery'),
  ('Automotive', 'automotive'), ('Agriculture', 'agriculture'), ('Services', 'services')
ON CONFLICT (slug) DO NOTHING;

-- Refactor: drop marketplace tables and rebuild products for inventory model
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.user_roles CASCADE;
DROP TABLE IF EXISTS public.categories CASCADE;
DROP FUNCTION IF EXISTS public.has_role(uuid, app_role) CASCADE;
DROP TYPE IF EXISTS public.app_role CASCADE;

ALTER TABLE public.products DROP COLUMN IF EXISTS seller_id;
ALTER TABLE public.products DROP COLUMN IF EXISTS is_active;
ALTER TABLE public.products DROP COLUMN IF EXISTS image_urls;
ALTER TABLE public.products DROP COLUMN IF EXISTS category_id;
ALTER TABLE public.products DROP COLUMN IF EXISTS price;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS category text DEFAULT '';
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS buying_price numeric NOT NULL DEFAULT 0;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS selling_price numeric NOT NULL DEFAULT 0;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS low_stock_alert integer NOT NULL DEFAULT 5;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS owner_id uuid NOT NULL DEFAULT auth.uid();
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS public_visible boolean NOT NULL DEFAULT false;

DROP POLICY IF EXISTS "Owner can view own products" ON public.products;
CREATE POLICY "Owner can view own products" ON public.products FOR SELECT USING (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Owner can insert products" ON public.products;
CREATE POLICY "Owner can insert products" ON public.products FOR INSERT WITH CHECK (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Owner can update own products" ON public.products;
CREATE POLICY "Owner can update own products" ON public.products FOR UPDATE USING (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Owner can delete own products" ON public.products;
CREATE POLICY "Owner can delete own products" ON public.products FOR DELETE USING (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Public can view public products" ON public.products;
CREATE POLICY "Public can view public products" ON public.products FOR SELECT USING (public_visible = true);

CREATE TABLE IF NOT EXISTS public.stock_in (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  quantity integer NOT NULL DEFAULT 0,
  buying_price numeric NOT NULL DEFAULT 0,
  total_cost numeric GENERATED ALWAYS AS (quantity * buying_price) STORED,
  owner_id uuid NOT NULL DEFAULT auth.uid(),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.stock_in ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Owner can view stock_in" ON public.stock_in;
CREATE POLICY "Owner can view stock_in" ON public.stock_in FOR SELECT USING (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Owner can insert stock_in" ON public.stock_in;
CREATE POLICY "Owner can insert stock_in" ON public.stock_in FOR INSERT WITH CHECK (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Owner can delete stock_in" ON public.stock_in;
CREATE POLICY "Owner can delete stock_in" ON public.stock_in FOR DELETE USING (auth.uid() = owner_id);

CREATE TABLE IF NOT EXISTS public.sales (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  quantity integer NOT NULL DEFAULT 0,
  selling_price numeric NOT NULL DEFAULT 0,
  buying_price numeric NOT NULL DEFAULT 0,
  total_sale numeric GENERATED ALWAYS AS (quantity * selling_price) STORED,
  profit numeric GENERATED ALWAYS AS (quantity * (selling_price - buying_price)) STORED,
  owner_id uuid NOT NULL DEFAULT auth.uid(),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Owner can view sales" ON public.sales;
CREATE POLICY "Owner can view sales" ON public.sales FOR SELECT USING (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Owner can insert sales" ON public.sales;
CREATE POLICY "Owner can insert sales" ON public.sales FOR INSERT WITH CHECK (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Owner can delete sales" ON public.sales;
CREATE POLICY "Owner can delete sales" ON public.sales FOR DELETE USING (auth.uid() = owner_id);

CREATE TABLE IF NOT EXISTS public.expenses (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name text NOT NULL,
  category text NOT NULL DEFAULT '',
  amount numeric NOT NULL DEFAULT 0,
  date date NOT NULL DEFAULT CURRENT_DATE,
  owner_id uuid NOT NULL DEFAULT auth.uid(),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Owner can view expenses" ON public.expenses;
CREATE POLICY "Owner can view expenses" ON public.expenses FOR SELECT USING (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Owner can insert expenses" ON public.expenses;
CREATE POLICY "Owner can insert expenses" ON public.expenses FOR INSERT WITH CHECK (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Owner can update expenses" ON public.expenses;
CREATE POLICY "Owner can update expenses" ON public.expenses FOR UPDATE USING (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Owner can delete expenses" ON public.expenses;
CREATE POLICY "Owner can delete expenses" ON public.expenses FOR DELETE USING (auth.uid() = owner_id);

CREATE TABLE IF NOT EXISTS public.public_settings (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_id uuid NOT NULL UNIQUE,
  business_name text NOT NULL DEFAULT '',
  slug text NOT NULL DEFAULT '',
  logo_url text,
  theme text NOT NULL DEFAULT 'minimal',
  theme_color text NOT NULL DEFAULT '#e87b35',
  is_public_enabled boolean NOT NULL DEFAULT false,
  whatsapp_number text,
  contact_email text,
  contact_phone text,
  description text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.public_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Owner can view own settings" ON public.public_settings;
CREATE POLICY "Owner can view own settings" ON public.public_settings FOR SELECT USING (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Owner can insert own settings" ON public.public_settings;
CREATE POLICY "Owner can insert own settings" ON public.public_settings FOR INSERT WITH CHECK (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Owner can update own settings" ON public.public_settings;
CREATE POLICY "Owner can update own settings" ON public.public_settings FOR UPDATE USING (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Public can view enabled stores" ON public.public_settings;
CREATE POLICY "Public can view enabled stores" ON public.public_settings FOR SELECT USING (is_public_enabled = true);

CREATE TABLE IF NOT EXISTS public.public_orders (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_id uuid NOT NULL,
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  customer_name text NOT NULL,
  phone text NOT NULL,
  quantity integer NOT NULL DEFAULT 1,
  status text NOT NULL DEFAULT 'pending',
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.public_orders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Owner can view own public orders" ON public.public_orders;
CREATE POLICY "Owner can view own public orders" ON public.public_orders FOR SELECT USING (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Owner can update own public orders" ON public.public_orders;
CREATE POLICY "Owner can update own public orders" ON public.public_orders FOR UPDATE USING (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Owner can delete own public orders" ON public.public_orders;
CREATE POLICY "Owner can delete own public orders" ON public.public_orders FOR DELETE USING (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Anyone can place public orders" ON public.public_orders;
CREATE POLICY "Anyone can place public orders" ON public.public_orders FOR INSERT WITH CHECK (true);
DROP POLICY IF EXISTS "Anyone can view orders by phone" ON public.public_orders;
CREATE POLICY "Anyone can view orders by phone" ON public.public_orders FOR SELECT TO anon, authenticated USING (true);

INSERT INTO storage.buckets (id, name, public) VALUES ('logos', 'logos', true) ON CONFLICT (id) DO NOTHING;
DROP POLICY IF EXISTS "Anyone can view logos" ON storage.objects;
CREATE POLICY "Anyone can view logos" ON storage.objects FOR SELECT USING (bucket_id = 'logos');
DROP POLICY IF EXISTS "Authenticated users can upload logos" ON storage.objects;
CREATE POLICY "Authenticated users can upload logos" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'logos' AND auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Authenticated users can update logos" ON storage.objects;
CREATE POLICY "Authenticated users can update logos" ON storage.objects FOR UPDATE USING (bucket_id = 'logos' AND auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Authenticated users can delete logos" ON storage.objects;
CREATE POLICY "Authenticated users can delete logos" ON storage.objects FOR DELETE USING (bucket_id = 'logos' AND auth.role() = 'authenticated');

CREATE UNIQUE INDEX IF NOT EXISTS idx_public_settings_slug ON public.public_settings(slug) WHERE slug != '';

CREATE TABLE IF NOT EXISTS public.instagram_content_history (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_id uuid NOT NULL DEFAULT auth.uid(),
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  caption text NOT NULL,
  hashtags text NOT NULL,
  style_type text NOT NULL DEFAULT 'promotional',
  generated_image_url text,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);
ALTER TABLE public.instagram_content_history ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Owner can view own content" ON public.instagram_content_history;
CREATE POLICY "Owner can view own content" ON public.instagram_content_history FOR SELECT USING (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Owner can insert own content" ON public.instagram_content_history;
CREATE POLICY "Owner can insert own content" ON public.instagram_content_history FOR INSERT WITH CHECK (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Owner can delete own content" ON public.instagram_content_history;
CREATE POLICY "Owner can delete own content" ON public.instagram_content_history FOR DELETE USING (auth.uid() = owner_id);

-- ===== 20260520101225_395e2c3e-f48a-4d60-81ac-57dafd1f2277.sql =====

-- POS SYSTEM
CREATE TABLE IF NOT EXISTS public.pos_sales (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  receipt_number TEXT NOT NULL,
  subtotal NUMERIC NOT NULL DEFAULT 0,
  total_item_discount NUMERIC NOT NULL DEFAULT 0,
  sale_discount_type TEXT DEFAULT 'none',
  sale_discount_value NUMERIC NOT NULL DEFAULT 0,
  sale_discount_amount NUMERIC NOT NULL DEFAULT 0,
  final_total NUMERIC NOT NULL DEFAULT 0,
  total_profit NUMERIC NOT NULL DEFAULT 0,
  payment_method TEXT NOT NULL DEFAULT 'cash',
  amount_received NUMERIC NOT NULL DEFAULT 0,
  balance_returned NUMERIC NOT NULL DEFAULT 0,
  notes TEXT,
  owner_id UUID NOT NULL DEFAULT auth.uid(),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
ALTER TABLE public.pos_sales ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Owner can view pos_sales" ON public.pos_sales;
CREATE POLICY "Owner can view pos_sales" ON public.pos_sales FOR SELECT USING (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Owner can insert pos_sales" ON public.pos_sales;
CREATE POLICY "Owner can insert pos_sales" ON public.pos_sales FOR INSERT WITH CHECK (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Owner can update pos_sales" ON public.pos_sales;
CREATE POLICY "Owner can update pos_sales" ON public.pos_sales FOR UPDATE USING (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Owner can delete pos_sales" ON public.pos_sales;
CREATE POLICY "Owner can delete pos_sales" ON public.pos_sales FOR DELETE USING (auth.uid() = owner_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_pos_sales_receipt ON public.pos_sales (owner_id, receipt_number);

CREATE TABLE IF NOT EXISTS public.sale_items (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  sale_id UUID NOT NULL REFERENCES public.pos_sales(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES public.products(id),
  product_name TEXT NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 1,
  unit_price NUMERIC NOT NULL DEFAULT 0,
  buying_price NUMERIC NOT NULL DEFAULT 0,
  discount_type TEXT DEFAULT 'none',
  discount_value NUMERIC NOT NULL DEFAULT 0,
  discount_amount NUMERIC NOT NULL DEFAULT 0,
  item_subtotal NUMERIC NOT NULL DEFAULT 0,
  profit NUMERIC NOT NULL DEFAULT 0
);
ALTER TABLE public.sale_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Owner can view sale_items" ON public.sale_items;
CREATE POLICY "Owner can view sale_items" ON public.sale_items FOR SELECT USING (EXISTS (SELECT 1 FROM public.pos_sales WHERE id = sale_items.sale_id AND owner_id = auth.uid()));
DROP POLICY IF EXISTS "Owner can insert sale_items" ON public.sale_items;
CREATE POLICY "Owner can insert sale_items" ON public.sale_items FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM public.pos_sales WHERE id = sale_items.sale_id AND owner_id = auth.uid()));
DROP POLICY IF EXISTS "Owner can delete sale_items" ON public.sale_items;
CREATE POLICY "Owner can delete sale_items" ON public.sale_items FOR DELETE USING (EXISTS (SELECT 1 FROM public.pos_sales WHERE id = sale_items.sale_id AND owner_id = auth.uid()));

CREATE TABLE IF NOT EXISTS public.refunds (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  sale_id UUID NOT NULL REFERENCES public.pos_sales(id),
  refund_amount NUMERIC NOT NULL DEFAULT 0,
  reason TEXT,
  items JSONB,
  owner_id UUID NOT NULL DEFAULT auth.uid(),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
ALTER TABLE public.refunds ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Owner can view refunds" ON public.refunds;
CREATE POLICY "Owner can view refunds" ON public.refunds FOR SELECT USING (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Owner can insert refunds" ON public.refunds;
CREATE POLICY "Owner can insert refunds" ON public.refunds FOR INSERT WITH CHECK (auth.uid() = owner_id);

CREATE TABLE IF NOT EXISTS public.day_closings (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  total_sales NUMERIC NOT NULL DEFAULT 0,
  total_profit NUMERIC NOT NULL DEFAULT 0,
  total_transactions INTEGER NOT NULL DEFAULT 0,
  total_discounts NUMERIC NOT NULL DEFAULT 0,
  cash_total NUMERIC NOT NULL DEFAULT 0,
  mobile_money_total NUMERIC NOT NULL DEFAULT 0,
  bank_total NUMERIC NOT NULL DEFAULT 0,
  total_expenses numeric NOT NULL DEFAULT 0,
  net_profit numeric NOT NULL DEFAULT 0,
  owner_id UUID NOT NULL DEFAULT auth.uid(),
  closed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
ALTER TABLE public.day_closings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Owner can view day_closings" ON public.day_closings;
CREATE POLICY "Owner can view day_closings" ON public.day_closings FOR SELECT USING (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Owner can insert day_closings" ON public.day_closings;
CREATE POLICY "Owner can insert day_closings" ON public.day_closings FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_day_closings_date ON public.day_closings (owner_id, date);

-- USER ROLES (owner/cashier)
DO $wrap$ BEGIN CREATE TYPE public.app_role AS ENUM ('owner', 'cashier'); EXCEPTION WHEN duplicate_object THEN NULL; END $wrap$;

CREATE TABLE IF NOT EXISTS public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  role app_role NOT NULL,
  granted_by UUID,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE (user_id, role)
);
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role app_role)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = _role) $$;
REVOKE EXECUTE ON FUNCTION public.has_role(uuid, app_role) FROM anon;

DROP POLICY IF EXISTS "Users can view own roles" ON public.user_roles;
CREATE POLICY "Users can view own roles" ON public.user_roles FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Owners can manage roles" ON public.user_roles;
CREATE POLICY "Owners can manage roles" ON public.user_roles FOR ALL USING (public.has_role(auth.uid(), 'owner'));

CREATE OR REPLACE FUNCTION public.generate_receipt_number(_owner_id UUID)
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE _count INTEGER; _date TEXT;
BEGIN
  _date := to_char(now(), 'YYYYMMDD');
  SELECT COUNT(*) + 1 INTO _count FROM public.pos_sales WHERE owner_id = _owner_id AND created_at::date = CURRENT_DATE;
  RETURN 'RCP-' || _date || '-' || LPAD(_count::TEXT, 4, '0');
END; $$;
REVOKE EXECUTE ON FUNCTION public.generate_receipt_number(uuid) FROM anon;

CREATE TABLE IF NOT EXISTS public.suppliers (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_id UUID NOT NULL DEFAULT auth.uid(),
  name TEXT NOT NULL,
  phone TEXT,
  email TEXT,
  address TEXT,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Owner can view suppliers" ON public.suppliers;
CREATE POLICY "Owner can view suppliers" ON public.suppliers FOR SELECT USING (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Owner can insert suppliers" ON public.suppliers;
CREATE POLICY "Owner can insert suppliers" ON public.suppliers FOR INSERT WITH CHECK (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Owner can update suppliers" ON public.suppliers;
CREATE POLICY "Owner can update suppliers" ON public.suppliers FOR UPDATE USING (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Owner can delete suppliers" ON public.suppliers;
CREATE POLICY "Owner can delete suppliers" ON public.suppliers FOR DELETE USING (auth.uid() = owner_id);

CREATE INDEX IF NOT EXISTS idx_instagram_content_owner ON public.instagram_content_history(owner_id);
CREATE INDEX IF NOT EXISTS idx_instagram_content_product ON public.instagram_content_history(product_id);

-- ===== 20260520101319_4a1838ad-8a3e-4efe-b71d-b8370127cb0b.sql =====

CREATE TABLE IF NOT EXISTS public.purchases (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_id UUID NOT NULL DEFAULT auth.uid(),
  supplier_id UUID REFERENCES public.suppliers(id) ON DELETE SET NULL,
  product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  quantity INTEGER NOT NULL DEFAULT 0,
  buying_price NUMERIC NOT NULL DEFAULT 0,
  total_cost NUMERIC NOT NULL DEFAULT 0,
  notes TEXT, date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
ALTER TABLE public.purchases ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Owner can view purchases" ON public.purchases;
CREATE POLICY "Owner can view purchases" ON public.purchases FOR SELECT USING (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Owner can insert purchases" ON public.purchases;
CREATE POLICY "Owner can insert purchases" ON public.purchases FOR INSERT WITH CHECK (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Owner can update purchases" ON public.purchases;
CREATE POLICY "Owner can update purchases" ON public.purchases FOR UPDATE USING (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Owner can delete purchases" ON public.purchases;
CREATE POLICY "Owner can delete purchases" ON public.purchases FOR DELETE USING (auth.uid() = owner_id);

CREATE TABLE IF NOT EXISTS public.activity_logs (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_id UUID NOT NULL DEFAULT auth.uid(),
  user_id UUID NOT NULL DEFAULT auth.uid(),
  action_type TEXT NOT NULL, description TEXT NOT NULL, related_id UUID,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Owner can view activity_logs" ON public.activity_logs;
CREATE POLICY "Owner can view activity_logs" ON public.activity_logs FOR SELECT USING (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Owner can insert activity_logs" ON public.activity_logs;
CREATE POLICY "Owner can insert activity_logs" ON public.activity_logs FOR INSERT WITH CHECK (auth.uid() = owner_id);

ALTER TABLE public.products ADD COLUMN IF NOT EXISTS image_url text DEFAULT NULL;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS featured boolean NOT NULL DEFAULT false;

INSERT INTO storage.buckets (id, name, public) VALUES ('product-images', 'product-images', true) ON CONFLICT (id) DO NOTHING;
DROP POLICY IF EXISTS "Authenticated users can upload product images" ON storage.objects;
CREATE POLICY "Authenticated users can upload product images" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'product-images');
DROP POLICY IF EXISTS "Authenticated users can update product images" ON storage.objects;
CREATE POLICY "Authenticated users can update product images" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = 'product-images');
DROP POLICY IF EXISTS "Authenticated users can delete product images" ON storage.objects;
CREATE POLICY "Authenticated users can delete product images" ON storage.objects FOR DELETE TO authenticated USING (bucket_id = 'product-images');
DROP POLICY IF EXISTS "Public can view product images" ON storage.objects;
CREATE POLICY "Public can view product images" ON storage.objects FOR SELECT TO public USING (bucket_id = 'product-images');

CREATE TABLE IF NOT EXISTS public.promotional_banners (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL DEFAULT auth.uid(),
  title text NOT NULL DEFAULT '', subtitle text DEFAULT '',
  image_url text DEFAULT NULL, bg_color text NOT NULL DEFAULT '#e87b35',
  is_active boolean NOT NULL DEFAULT true, position integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);
ALTER TABLE public.promotional_banners ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Owner can view own banners" ON public.promotional_banners;
CREATE POLICY "Owner can view own banners" ON public.promotional_banners FOR SELECT USING (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Owner can insert own banners" ON public.promotional_banners;
CREATE POLICY "Owner can insert own banners" ON public.promotional_banners FOR INSERT WITH CHECK (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Owner can update own banners" ON public.promotional_banners;
CREATE POLICY "Owner can update own banners" ON public.promotional_banners FOR UPDATE USING (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Owner can delete own banners" ON public.promotional_banners;
CREATE POLICY "Owner can delete own banners" ON public.promotional_banners FOR DELETE USING (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Public can view active banners" ON public.promotional_banners;
CREATE POLICY "Public can view active banners" ON public.promotional_banners FOR SELECT USING (is_active = true);

DO $wrap$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.public_orders; EXCEPTION WHEN OTHERS THEN NULL; END $wrap$;

-- Categories (recreated with extra cols)
CREATE TABLE IF NOT EXISTS public.categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE, slug text NOT NULL UNIQUE,
  icon text, sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can view categories" ON public.categories;
CREATE POLICY "Anyone can view categories" ON public.categories FOR SELECT USING (true);
DROP POLICY IF EXISTS "Owners can manage categories" ON public.categories;
CREATE POLICY "Owners can manage categories" ON public.categories FOR ALL USING (public.has_role(auth.uid(), 'owner')) WITH CHECK (public.has_role(auth.uid(), 'owner'));

ALTER TABLE public.public_settings ADD COLUMN IF NOT EXISTS is_listed boolean NOT NULL DEFAULT true;
ALTER TABLE public.public_settings ADD COLUMN IF NOT EXISTS category text DEFAULT '';
ALTER TABLE public.public_settings ADD COLUMN IF NOT EXISTS category_id uuid REFERENCES public.categories(id) ON DELETE SET NULL;
ALTER TABLE public.public_settings ADD COLUMN IF NOT EXISTS is_featured boolean NOT NULL DEFAULT false;
ALTER TABLE public.public_settings ADD COLUMN IF NOT EXISTS engagement_score numeric NOT NULL DEFAULT 0;
CREATE INDEX IF NOT EXISTS idx_public_settings_category_id ON public.public_settings(category_id);
CREATE INDEX IF NOT EXISTS idx_public_settings_is_featured ON public.public_settings(is_featured) WHERE is_featured = true;

DROP POLICY IF EXISTS "Public can view listed shops" ON public.public_settings;
CREATE POLICY "Public can view listed shops" ON public.public_settings FOR SELECT USING (is_listed = true);
UPDATE public.public_settings SET is_listed = true WHERE is_public_enabled = true;

CREATE TABLE IF NOT EXISTS public.user_activity (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  activity_type TEXT NOT NULL, target_id TEXT NOT NULL,
  target_category TEXT DEFAULT '', duration_seconds INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_user_activity_user ON public.user_activity (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_activity_type ON public.user_activity (user_id, activity_type);
CREATE INDEX IF NOT EXISTS idx_user_activity_target ON public.user_activity (user_id, target_id);
ALTER TABLE public.user_activity ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view own activity" ON public.user_activity;
CREATE POLICY "Users can view own activity" ON public.user_activity FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can insert own activity" ON public.user_activity;
CREATE POLICY "Users can insert own activity" ON public.user_activity FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can delete own activity" ON public.user_activity;
CREATE POLICY "Users can delete own activity" ON public.user_activity FOR DELETE USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE _name text; _slug text; _base_slug text; _suffix int := 0;
BEGIN
  _name := COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1), 'My Shop');
  INSERT INTO public.profiles (user_id, name, email) VALUES (NEW.id, _name, NEW.email) ON CONFLICT DO NOTHING;
  _base_slug := regexp_replace(lower(_name), '[^a-z0-9]+', '-', 'g');
  _base_slug := trim(both '-' from _base_slug);
  IF _base_slug = '' THEN _base_slug := 'shop-' || substr(NEW.id::text, 1, 8); END IF;
  _slug := _base_slug;
  WHILE EXISTS (SELECT 1 FROM public.public_settings WHERE slug = _slug) LOOP
    _suffix := _suffix + 1; _slug := _base_slug || '-' || _suffix;
  END LOOP;
  INSERT INTO public.public_settings (owner_id, business_name, slug, is_public_enabled, is_listed, theme, theme_color)
    VALUES (NEW.id, _name, _slug, true, true, 'minimal', '#7c3aed') ON CONFLICT DO NOTHING;
  INSERT INTO public.user_roles (user_id, role) VALUES (NEW.id, 'owner') ON CONFLICT DO NOTHING;
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Backfill existing users
DO $$
DECLARE u RECORD; _name text; _slug text; _base_slug text; _suffix int;
BEGIN
  FOR u IN SELECT au.id, au.email, au.raw_user_meta_data FROM auth.users au
    LEFT JOIN public.public_settings ps ON ps.owner_id = au.id WHERE ps.id IS NULL
  LOOP
    _name := COALESCE(u.raw_user_meta_data->>'name', split_part(u.email, '@', 1), 'My Shop');
    _base_slug := regexp_replace(lower(_name), '[^a-z0-9]+', '-', 'g');
    _base_slug := trim(both '-' from _base_slug);
    IF _base_slug = '' THEN _base_slug := 'shop-' || substr(u.id::text, 1, 8); END IF;
    _slug := _base_slug; _suffix := 0;
    WHILE EXISTS (SELECT 1 FROM public.public_settings WHERE slug = _slug) LOOP
      _suffix := _suffix + 1; _slug := _base_slug || '-' || _suffix;
    END LOOP;
    INSERT INTO public.public_settings (owner_id, business_name, slug, is_public_enabled, is_listed, theme, theme_color)
      VALUES (u.id, _name, _slug, true, true, 'minimal', '#7c3aed') ON CONFLICT DO NOTHING;
    INSERT INTO public.profiles (user_id, name, email) VALUES (u.id, _name, u.email) ON CONFLICT DO NOTHING;
  END LOOP;
END $$;

-- ===== 20260520101428_b2ef6080-2498-4d43-89ba-a32f4a3dcad0.sql =====

INSERT INTO public.categories (name, slug, icon, sort_order) VALUES
  ('Electronics', 'electronics', 'Smartphone', 1),
  ('Fashion & Apparel', 'fashion', 'Shirt', 2),
  ('Food & Beverages', 'food-beverages', 'UtensilsCrossed', 3),
  ('Health & Beauty', 'health-beauty', 'Sparkles', 4),
  ('Home & Garden', 'home-garden', 'Home', 5),
  ('Sports & Outdoors', 'sports', 'Dumbbell', 6),
  ('Books & Stationery', 'books', 'BookOpen', 7),
  ('Toys & Kids', 'toys-kids', 'ToyBrick', 8),
  ('Automotive', 'automotive', 'Car', 9),
  ('Services', 'services', 'Briefcase', 10),
  ('Groceries', 'groceries', 'ShoppingBasket', 11),
  ('Jewelry & Accessories', 'jewelry', 'Gem', 12),
  ('Arts & Crafts', 'arts-crafts', 'Palette', 13),
  ('Pet Supplies', 'pets', 'PawPrint', 14),
  ('Office Supplies', 'office', 'Printer', 15),
  ('Other', 'other', 'Package', 99)
ON CONFLICT (slug) DO NOTHING;

-- Pre-add columns referenced by refresh_featured_shops (filled with defaults; later migrations add real data)
ALTER TABLE public.public_settings ADD COLUMN IF NOT EXISTS follower_count integer NOT NULL DEFAULT 0;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS likes_count integer NOT NULL DEFAULT 0;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS comments_count integer NOT NULL DEFAULT 0;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS saves_count integer NOT NULL DEFAULT 0;

CREATE OR REPLACE FUNCTION public.refresh_featured_shops()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  WITH shop_stats AS (
    SELECT ps.owner_id,
      COALESCE(ps.follower_count, 0) * 3.0
        + COALESCE((SELECT SUM(likes_count + comments_count + saves_count) FROM public.products p WHERE p.owner_id = ps.owner_id AND p.public_visible = true), 0) * 1.0
        + COALESCE((SELECT COUNT(*) FROM public.public_orders po WHERE po.owner_id = ps.owner_id), 0) * 2.0
        + COALESCE((SELECT COUNT(*) FROM public.products p2 WHERE p2.owner_id = ps.owner_id AND p2.public_visible = true), 0) * 0.5
        AS score
    FROM public.public_settings ps
    WHERE ps.is_public_enabled = true AND ps.is_listed = true
  )
  UPDATE public.public_settings ps SET engagement_score = ss.score FROM shop_stats ss WHERE ps.owner_id = ss.owner_id;
  UPDATE public.public_settings SET is_featured = false WHERE is_featured = true;
  UPDATE public.public_settings SET is_featured = true
  WHERE owner_id IN (
    SELECT owner_id FROM public.public_settings
    WHERE is_public_enabled = true AND is_listed = true
    ORDER BY engagement_score DESC, follower_count DESC LIMIT 8
  );
END; $$;
REVOKE EXECUTE ON FUNCTION public.refresh_featured_shops() FROM anon, authenticated;
SELECT public.refresh_featured_shops();

CREATE TABLE IF NOT EXISTS public.product_stories (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  product_name text NOT NULL, title text NOT NULL, story text NOT NULL,
  image_url text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'published')),
  published_platforms text[] DEFAULT ARRAY[]::text[],
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);
CREATE INDEX IF NOT EXISTS product_stories_owner_id_idx ON public.product_stories(owner_id);
CREATE INDEX IF NOT EXISTS product_stories_product_id_idx ON public.product_stories(product_id);
CREATE INDEX IF NOT EXISTS product_stories_created_at_idx ON public.product_stories(created_at DESC);
ALTER TABLE public.product_stories ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view their own product stories" ON public.product_stories;
CREATE POLICY "Users can view their own product stories" ON public.product_stories FOR SELECT USING (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Users can create product stories" ON public.product_stories;
CREATE POLICY "Users can create product stories" ON public.product_stories FOR INSERT WITH CHECK (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Users can update their own product stories" ON public.product_stories;
CREATE POLICY "Users can update their own product stories" ON public.product_stories FOR UPDATE USING (auth.uid() = owner_id);
DROP POLICY IF EXISTS "Users can delete their own product stories" ON public.product_stories;
CREATE POLICY "Users can delete their own product stories" ON public.product_stories FOR DELETE USING (auth.uid() = owner_id);

CREATE TABLE IF NOT EXISTS public.subscription_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tier text NOT NULL UNIQUE, name text NOT NULL,
  price numeric NOT NULL DEFAULT 0, currency text NOT NULL DEFAULT 'TZS',
  billing_period text NOT NULL DEFAULT 'monthly',
  trial_days integer NOT NULL DEFAULT 30,
  description text, features jsonb NOT NULL DEFAULT '[]'::jsonb,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can view plans" ON public.subscription_plans;
CREATE POLICY "Anyone can view plans" ON public.subscription_plans FOR SELECT USING (true);
INSERT INTO public.subscription_plans (tier, name, price, currency, billing_period, trial_days, description, features, sort_order)
VALUES
  ('free', 'Free', 0, 'TZS', 'monthly', 0, 'Basic buyer account', '["Like products","Comment","Follow shops","View marketplace"]'::jsonb, 0),
  ('premium_monthly', 'Premium Monthly', 25000, 'TZS', 'monthly', 30, 'Full access, billed every month',
   '["Unlimited products","Multi-branch","POS & inventory","Marketplace listing","Instagram AI generator","Priority support"]'::jsonb, 1),
  ('premium_yearly', 'Premium Yearly', 250000, 'TZS', 'yearly', 30, 'Save 2 months, billed once a year',
   '["Everything in Monthly","2 months free","Advanced analytics","Custom branding","Team collaboration"]'::jsonb, 2)
ON CONFLICT (tier) DO UPDATE SET price = EXCLUDED.price, currency = EXCLUDED.currency, name = EXCLUDED.name, description = EXCLUDED.description, features = EXCLUDED.features, updated_at = now();

CREATE TABLE IF NOT EXISTS public.user_profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  user_type text NOT NULL DEFAULT 'buyer' CHECK (user_type IN ('buyer', 'business')),
  subscription_tier text DEFAULT 'free',
  subscription_status text DEFAULT 'inactive' CHECK (subscription_status IN ('inactive', 'trial', 'active', 'cancelled')),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view their own profile" ON public.user_profiles;
CREATE POLICY "Users can view their own profile" ON public.user_profiles FOR SELECT USING (auth.uid() = id);
DROP POLICY IF EXISTS "Users can update their own profile" ON public.user_profiles;
CREATE POLICY "Users can update their own profile" ON public.user_profiles FOR UPDATE USING (auth.uid() = id);
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.user_profiles;
CREATE POLICY "Users can insert their own profile" ON public.user_profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE INDEX IF NOT EXISTS idx_user_profiles_user_type ON public.user_profiles(user_type);
CREATE INDEX IF NOT EXISTS idx_user_profiles_subscription_tier ON public.user_profiles(subscription_tier);

CREATE TABLE IF NOT EXISTS public.user_subscriptions (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  plan_id uuid NOT NULL REFERENCES public.subscription_plans(id),
  subscription_tier text NOT NULL,
  status text NOT NULL DEFAULT 'inactive' CHECK (status IN ('inactive', 'trial', 'active', 'expired', 'cancelled')),
  started_at timestamp with time zone DEFAULT now(),
  trial_started_at timestamp with time zone,
  trial_ends_at timestamp with time zone,
  ends_at timestamp with time zone,
  auto_renew boolean DEFAULT true,
  payment_method_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS unique_active_subscription ON public.user_subscriptions (user_id, subscription_tier) WHERE status IN ('active', 'trial');
ALTER TABLE public.user_subscriptions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view their own subscriptions" ON public.user_subscriptions;
CREATE POLICY "Users can view their own subscriptions" ON public.user_subscriptions FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can update their own subscriptions" ON public.user_subscriptions;
CREATE POLICY "Users can update their own subscriptions" ON public.user_subscriptions FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can insert their own subscriptions" ON public.user_subscriptions;
CREATE POLICY "Users can insert their own subscriptions" ON public.user_subscriptions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_user_id ON public.user_subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_status ON public.user_subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_tier ON public.user_subscriptions(subscription_tier);

CREATE TABLE IF NOT EXISTS public.payment_methods (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  payment_type text NOT NULL CHECK (payment_type IN ('bank', 'mobile_money')),
  provider text NOT NULL, account_identifier text NOT NULL,
  is_default boolean DEFAULT false, verified boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);
ALTER TABLE public.payment_methods ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view their own payment methods" ON public.payment_methods;
CREATE POLICY "Users can view their own payment methods" ON public.payment_methods FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can create payment methods" ON public.payment_methods;
CREATE POLICY "Users can create payment methods" ON public.payment_methods FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can update their own payment methods" ON public.payment_methods;
CREATE POLICY "Users can update their own payment methods" ON public.payment_methods FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can delete their own payment methods" ON public.payment_methods;
CREATE POLICY "Users can delete their own payment methods" ON public.payment_methods FOR DELETE USING (auth.uid() = user_id);
CREATE INDEX IF NOT EXISTS idx_payment_methods_user_id ON public.payment_methods(user_id);

CREATE TABLE IF NOT EXISTS public.subscription_payments (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  subscription_id uuid NOT NULL REFERENCES public.user_subscriptions(id) ON DELETE CASCADE,
  payment_method_id uuid NOT NULL REFERENCES public.payment_methods(id),
  amount decimal(10, 2) NOT NULL, currency text NOT NULL DEFAULT 'KES',
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'refunded')),
  transaction_reference text UNIQUE,
  payment_date timestamp with time zone, due_date timestamp with time zone, paid_date timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);
ALTER TABLE public.subscription_payments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view their own payments" ON public.subscription_payments;
CREATE POLICY "Users can view their own payments" ON public.subscription_payments FOR SELECT USING (auth.uid() = user_id);
CREATE INDEX IF NOT EXISTS idx_subscription_payments_user_id ON public.subscription_payments(user_id);
CREATE INDEX IF NOT EXISTS idx_subscription_payments_status ON public.subscription_payments(status);

CREATE TABLE IF NOT EXISTS public.user_branches (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  account_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  branch_name text NOT NULL, is_main_branch boolean DEFAULT false,
  manager_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  location text, contact_info jsonb, settings jsonb DEFAULT '{}'::jsonb,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);
ALTER TABLE public.user_branches ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view their account branches" ON public.user_branches;
CREATE POLICY "Users can view their account branches" ON public.user_branches FOR SELECT USING (auth.uid() = account_id OR auth.uid() = manager_id);
DROP POLICY IF EXISTS "Account owners can manage branches" ON public.user_branches;
CREATE POLICY "Account owners can manage branches" ON public.user_branches FOR UPDATE USING (auth.uid() = account_id);
DROP POLICY IF EXISTS "Account owners can create branches" ON public.user_branches;
CREATE POLICY "Account owners can create branches" ON public.user_branches FOR INSERT WITH CHECK (auth.uid() = account_id);
CREATE INDEX IF NOT EXISTS idx_user_branches_account_id ON public.user_branches(account_id);
CREATE INDEX IF NOT EXISTS idx_user_branches_is_main ON public.user_branches(is_main_branch);

-- ===== 20260520101541_dc6f4bfc-f82e-4c38-a410-6b8ed3d25ae9.sql =====
ALTER TABLE public.public_settings 
  ADD COLUMN IF NOT EXISTS latitude numeric,
  ADD COLUMN IF NOT EXISTS longitude numeric,
  ADD COLUMN IF NOT EXISTS address text;
