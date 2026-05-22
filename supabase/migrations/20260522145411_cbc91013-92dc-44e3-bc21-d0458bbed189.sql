
-- Create role enum
DO $wrap$ BEGIN CREATE TYPE public.app_role AS ENUM ('seller', 'customer'); EXCEPTION WHEN duplicate_object THEN NULL; END $wrap$;

CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
  name TEXT NOT NULL DEFAULT '',
  email TEXT NOT NULL DEFAULT '',
  phone TEXT, whatsapp TEXT, avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL, description TEXT,
  stock INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  category text DEFAULT '',
  buying_price numeric NOT NULL DEFAULT 0,
  selling_price numeric NOT NULL DEFAULT 0,
  low_stock_alert integer NOT NULL DEFAULT 5,
  owner_id uuid NOT NULL DEFAULT auth.uid(),
  public_visible boolean NOT NULL DEFAULT false,
  image_url text,
  featured boolean NOT NULL DEFAULT false,
  likes_count integer NOT NULL DEFAULT 0,
  comments_count integer NOT NULL DEFAULT 0,
  saves_count integer NOT NULL DEFAULT 0
);
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view profiles" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Owner can view own products" ON public.products FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert products" ON public.products FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Owner can update own products" ON public.products FOR UPDATE USING (auth.uid() = owner_id);
CREATE POLICY "Owner can delete own products" ON public.products FOR DELETE USING (auth.uid() = owner_id);
CREATE POLICY "Public can view public products" ON public.products FOR SELECT USING (public_visible = true);

CREATE TABLE IF NOT EXISTS public.stock_in (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  quantity integer NOT NULL DEFAULT 0,
  buying_price numeric NOT NULL DEFAULT 0,
  selling_price numeric NOT NULL DEFAULT 0,
  total_cost numeric GENERATED ALWAYS AS (quantity * buying_price) STORED,
  owner_id uuid NOT NULL DEFAULT auth.uid(),
  notes text, created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.stock_in ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner can view stock_in" ON public.stock_in FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert stock_in" ON public.stock_in FOR INSERT WITH CHECK (auth.uid() = owner_id);
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
  notes text, created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner can view sales" ON public.sales FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert sales" ON public.sales FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Owner can delete sales" ON public.sales FOR DELETE USING (auth.uid() = owner_id);

CREATE TABLE IF NOT EXISTS public.expenses (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name text NOT NULL, category text NOT NULL DEFAULT '',
  amount numeric NOT NULL DEFAULT 0,
  date date NOT NULL DEFAULT CURRENT_DATE,
  owner_id uuid NOT NULL DEFAULT auth.uid(),
  notes text, created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner can view expenses" ON public.expenses FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert expenses" ON public.expenses FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Owner can update expenses" ON public.expenses FOR UPDATE USING (auth.uid() = owner_id);
CREATE POLICY "Owner can delete expenses" ON public.expenses FOR DELETE USING (auth.uid() = owner_id);

CREATE TABLE IF NOT EXISTS public.categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE, slug text NOT NULL UNIQUE,
  icon text, sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view categories" ON public.categories FOR SELECT USING (true);

CREATE TABLE IF NOT EXISTS public.public_settings (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_id uuid NOT NULL UNIQUE,
  business_name text NOT NULL DEFAULT '',
  slug text NOT NULL DEFAULT '',
  logo_url text, theme text NOT NULL DEFAULT 'minimal',
  theme_color text NOT NULL DEFAULT '#e87b35',
  is_public_enabled boolean NOT NULL DEFAULT false,
  whatsapp_number text, contact_email text, contact_phone text,
  description text,
  is_listed boolean NOT NULL DEFAULT true,
  category text DEFAULT '',
  category_id uuid REFERENCES public.categories(id) ON DELETE SET NULL,
  is_featured boolean NOT NULL DEFAULT false,
  engagement_score numeric NOT NULL DEFAULT 0,
  follower_count integer NOT NULL DEFAULT 0,
  latitude double precision, longitude double precision,
  address text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.public_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner can view own settings" ON public.public_settings FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert own settings" ON public.public_settings FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Owner can update own settings" ON public.public_settings FOR UPDATE USING (auth.uid() = owner_id);
CREATE POLICY "Public can view enabled stores" ON public.public_settings FOR SELECT USING (is_public_enabled = true);
CREATE POLICY "Public can view listed shops" ON public.public_settings FOR SELECT USING (is_listed = true);
CREATE UNIQUE INDEX IF NOT EXISTS idx_public_settings_slug ON public.public_settings(slug) WHERE slug != '';

CREATE TABLE IF NOT EXISTS public.public_orders (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_id uuid NOT NULL,
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  customer_name text NOT NULL, phone text NOT NULL,
  quantity integer NOT NULL DEFAULT 1,
  status text NOT NULL DEFAULT 'pending',
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.public_orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner can view own public orders" ON public.public_orders FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can update own public orders" ON public.public_orders FOR UPDATE USING (auth.uid() = owner_id);
CREATE POLICY "Owner can delete own public orders" ON public.public_orders FOR DELETE USING (auth.uid() = owner_id);
CREATE POLICY "Anyone can place public orders" ON public.public_orders FOR INSERT WITH CHECK (true);
CREATE POLICY "Anyone can view orders by phone" ON public.public_orders FOR SELECT TO anon, authenticated USING (true);

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
  notes TEXT, owner_id UUID NOT NULL DEFAULT auth.uid(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.pos_sales ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner can view pos_sales" ON public.pos_sales FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert pos_sales" ON public.pos_sales FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Owner can update pos_sales" ON public.pos_sales FOR UPDATE USING (auth.uid() = owner_id);
CREATE POLICY "Owner can delete pos_sales" ON public.pos_sales FOR DELETE USING (auth.uid() = owner_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_pos_sales_receipt ON public.pos_sales (owner_id, receipt_number);

CREATE TABLE IF NOT EXISTS public.sale_items (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  sale_id UUID NOT NULL REFERENCES public.pos_sales(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES public.products(id),
  product_name TEXT NOT NULL, quantity INTEGER NOT NULL DEFAULT 1,
  unit_price NUMERIC NOT NULL DEFAULT 0,
  buying_price NUMERIC NOT NULL DEFAULT 0,
  discount_type TEXT DEFAULT 'none',
  discount_value NUMERIC NOT NULL DEFAULT 0,
  discount_amount NUMERIC NOT NULL DEFAULT 0,
  item_subtotal NUMERIC NOT NULL DEFAULT 0,
  profit NUMERIC NOT NULL DEFAULT 0
);
ALTER TABLE public.sale_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner can view sale_items" ON public.sale_items FOR SELECT USING (EXISTS (SELECT 1 FROM public.pos_sales WHERE id = sale_items.sale_id AND owner_id = auth.uid()));
CREATE POLICY "Owner can insert sale_items" ON public.sale_items FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM public.pos_sales WHERE id = sale_items.sale_id AND owner_id = auth.uid()));
CREATE POLICY "Owner can delete sale_items" ON public.sale_items FOR DELETE USING (EXISTS (SELECT 1 FROM public.pos_sales WHERE id = sale_items.sale_id AND owner_id = auth.uid()));

CREATE TABLE IF NOT EXISTS public.refunds (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  sale_id UUID NOT NULL REFERENCES public.pos_sales(id),
  refund_amount NUMERIC NOT NULL DEFAULT 0,
  reason TEXT, items JSONB,
  owner_id UUID NOT NULL DEFAULT auth.uid(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.refunds ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner can view refunds" ON public.refunds FOR SELECT USING (auth.uid() = owner_id);
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
  closed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.day_closings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner can view day_closings" ON public.day_closings FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert day_closings" ON public.day_closings FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_day_closings_date ON public.day_closings (owner_id, date);

DO $wrap$ BEGIN CREATE TYPE public.app_role_v2 AS ENUM ('owner', 'cashier'); EXCEPTION WHEN duplicate_object THEN NULL; END $wrap$;

CREATE TABLE IF NOT EXISTS public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  role app_role_v2 NOT NULL,
  granted_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, role)
);
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role app_role_v2)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = _role) $$;
REVOKE EXECUTE ON FUNCTION public.has_role(uuid, app_role_v2) FROM anon;

CREATE POLICY "Users can view own roles" ON public.user_roles FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Owners can manage roles" ON public.user_roles FOR ALL USING (public.has_role(auth.uid(), 'owner'));

CREATE OR REPLACE FUNCTION public.generate_receipt_number(_owner_id UUID)
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$ DECLARE _count INTEGER; _date TEXT; BEGIN
  _date := to_char(now(), 'YYYYMMDD');
  SELECT COUNT(*) + 1 INTO _count FROM public.pos_sales WHERE owner_id = _owner_id AND created_at::date = CURRENT_DATE;
  RETURN 'RCP-' || _date || '-' || LPAD(_count::TEXT, 4, '0');
END; $$;

CREATE TABLE IF NOT EXISTS public.suppliers (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_id UUID NOT NULL DEFAULT auth.uid(),
  name TEXT NOT NULL, phone TEXT, email TEXT, address TEXT, notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner can view suppliers" ON public.suppliers FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert suppliers" ON public.suppliers FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Owner can update suppliers" ON public.suppliers FOR UPDATE USING (auth.uid() = owner_id);
CREATE POLICY "Owner can delete suppliers" ON public.suppliers FOR DELETE USING (auth.uid() = owner_id);

CREATE TABLE IF NOT EXISTS public.purchases (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_id UUID NOT NULL DEFAULT auth.uid(),
  supplier_id UUID REFERENCES public.suppliers(id) ON DELETE SET NULL,
  product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  quantity INTEGER NOT NULL DEFAULT 0,
  buying_price NUMERIC NOT NULL DEFAULT 0,
  total_cost NUMERIC NOT NULL DEFAULT 0,
  notes TEXT, date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.purchases ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner can view purchases" ON public.purchases FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert purchases" ON public.purchases FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Owner can update purchases" ON public.purchases FOR UPDATE USING (auth.uid() = owner_id);
CREATE POLICY "Owner can delete purchases" ON public.purchases FOR DELETE USING (auth.uid() = owner_id);

CREATE TABLE IF NOT EXISTS public.activity_logs (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_id UUID NOT NULL DEFAULT auth.uid(),
  user_id UUID NOT NULL DEFAULT auth.uid(),
  action_type TEXT NOT NULL, description TEXT NOT NULL, related_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner can view activity_logs" ON public.activity_logs FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert activity_logs" ON public.activity_logs FOR INSERT WITH CHECK (auth.uid() = owner_id);

CREATE TABLE IF NOT EXISTS public.instagram_content_history (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_id uuid NOT NULL DEFAULT auth.uid(),
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  caption text NOT NULL, hashtags text NOT NULL,
  style_type text NOT NULL DEFAULT 'promotional',
  generated_image_url text,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.instagram_content_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner can view own content" ON public.instagram_content_history FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert own content" ON public.instagram_content_history FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Owner can delete own content" ON public.instagram_content_history FOR DELETE USING (auth.uid() = owner_id);

CREATE TABLE IF NOT EXISTS public.promotional_banners (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL DEFAULT auth.uid(),
  title text NOT NULL DEFAULT '', subtitle text DEFAULT '',
  image_url text, bg_color text NOT NULL DEFAULT '#e87b35',
  is_active boolean NOT NULL DEFAULT true, position integer NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.promotional_banners ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owner can view own banners" ON public.promotional_banners FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Owner can insert own banners" ON public.promotional_banners FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Owner can update own banners" ON public.promotional_banners FOR UPDATE USING (auth.uid() = owner_id);
CREATE POLICY "Owner can delete own banners" ON public.promotional_banners FOR DELETE USING (auth.uid() = owner_id);
CREATE POLICY "Public can view active banners" ON public.promotional_banners FOR SELECT USING (is_active = true);

CREATE TABLE IF NOT EXISTS public.user_activity (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  activity_type TEXT NOT NULL, target_id TEXT NOT NULL,
  target_category TEXT DEFAULT '', duration_seconds INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.user_activity ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own activity" ON public.user_activity FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own activity" ON public.user_activity FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete own activity" ON public.user_activity FOR DELETE USING (auth.uid() = user_id);

CREATE TABLE IF NOT EXISTS public.product_stories (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  product_name text NOT NULL, title text NOT NULL, story text NOT NULL,
  image_url text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published')),
  published_platforms text[] DEFAULT ARRAY[]::text[],
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.product_stories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own stories" ON public.product_stories FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Users insert stories" ON public.product_stories FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Users update own stories" ON public.product_stories FOR UPDATE USING (auth.uid() = owner_id);
CREATE POLICY "Users delete own stories" ON public.product_stories FOR DELETE USING (auth.uid() = owner_id);

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
CREATE POLICY "Anyone can view plans" ON public.subscription_plans FOR SELECT USING (true);

CREATE TABLE IF NOT EXISTS public.user_profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  user_type text NOT NULL DEFAULT 'buyer' CHECK (user_type IN ('buyer','business')),
  subscription_tier text DEFAULT 'free',
  subscription_status text DEFAULT 'inactive' CHECK (subscription_status IN ('inactive','trial','active','cancelled')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own user_profile" ON public.user_profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users update own user_profile" ON public.user_profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users insert own user_profile" ON public.user_profiles FOR INSERT WITH CHECK (auth.uid() = id);

CREATE TABLE IF NOT EXISTS public.user_subscriptions (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  plan_id uuid NOT NULL REFERENCES public.subscription_plans(id),
  subscription_tier text NOT NULL,
  status text NOT NULL DEFAULT 'inactive' CHECK (status IN ('inactive','trial','active','expired','cancelled')),
  started_at TIMESTAMPTZ DEFAULT now(),
  trial_started_at TIMESTAMPTZ, trial_ends_at TIMESTAMPTZ, ends_at TIMESTAMPTZ,
  auto_renew boolean DEFAULT true,
  payment_method_id uuid,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.user_subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own subs" ON public.user_subscriptions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users update own subs" ON public.user_subscriptions FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users insert own subs" ON public.user_subscriptions FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE TABLE IF NOT EXISTS public.payment_methods (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  payment_type text NOT NULL CHECK (payment_type IN ('bank','mobile_money')),
  provider text NOT NULL, account_identifier text NOT NULL,
  is_default boolean DEFAULT false, verified boolean DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.payment_methods ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own pm" ON public.payment_methods FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users insert pm" ON public.payment_methods FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users update own pm" ON public.payment_methods FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users delete own pm" ON public.payment_methods FOR DELETE USING (auth.uid() = user_id);

CREATE TABLE IF NOT EXISTS public.user_branches (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  account_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  branch_name text NOT NULL, is_main_branch boolean DEFAULT false,
  manager_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  location text, contact_info jsonb, settings jsonb DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.user_branches ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view branches" ON public.user_branches FOR SELECT USING (auth.uid() = account_id OR auth.uid() = manager_id);
CREATE POLICY "Owners update branches" ON public.user_branches FOR UPDATE USING (auth.uid() = account_id);
CREATE POLICY "Owners create branches" ON public.user_branches FOR INSERT WITH CHECK (auth.uid() = account_id);

-- Storage buckets
INSERT INTO storage.buckets (id, name, public) VALUES ('logos','logos',true) ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('product-images','product-images',true) ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('media','media',true) ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Public view logos" ON storage.objects FOR SELECT USING (bucket_id = 'logos');
CREATE POLICY "Auth upload logos" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'logos');
CREATE POLICY "Auth update logos" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = 'logos');
CREATE POLICY "Auth delete logos" ON storage.objects FOR DELETE TO authenticated USING (bucket_id = 'logos');
CREATE POLICY "Public view product-images" ON storage.objects FOR SELECT USING (bucket_id = 'product-images');
CREATE POLICY "Auth upload product-images" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'product-images');
CREATE POLICY "Auth update product-images" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = 'product-images');
CREATE POLICY "Auth delete product-images" ON storage.objects FOR DELETE TO authenticated USING (bucket_id = 'product-images');
CREATE POLICY "Public view media" ON storage.objects FOR SELECT USING (bucket_id = 'media');
CREATE POLICY "Auth upload media" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'media');

-- Trigger to auto-create profile + shop + role on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$ DECLARE _name text; _slug text; _base_slug text; _suffix int := 0;
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

DO $wrap$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.public_orders; EXCEPTION WHEN OTHERS THEN NULL; END $wrap$;

-- Seed categories and plans
INSERT INTO public.categories (name, slug, icon, sort_order) VALUES
  ('Electronics','electronics','Smartphone',1),
  ('Fashion & Apparel','fashion','Shirt',2),
  ('Food & Beverages','food-beverages','UtensilsCrossed',3),
  ('Health & Beauty','health-beauty','Sparkles',4),
  ('Home & Garden','home-garden','Home',5),
  ('Sports & Outdoors','sports','Dumbbell',6),
  ('Books & Stationery','books','BookOpen',7),
  ('Toys & Kids','toys-kids','ToyBrick',8),
  ('Automotive','automotive','Car',9),
  ('Services','services','Briefcase',10),
  ('Groceries','groceries','ShoppingBasket',11),
  ('Jewelry & Accessories','jewelry','Gem',12),
  ('Arts & Crafts','arts-crafts','Palette',13),
  ('Pet Supplies','pets','PawPrint',14),
  ('Office Supplies','office','Printer',15),
  ('Other','other','Package',99)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.subscription_plans (tier, name, price, currency, billing_period, trial_days, description, features, sort_order)
VALUES
  ('free','Free',0,'TZS','monthly',0,'Basic buyer account','["Like products","Comment","Follow shops","View marketplace"]'::jsonb,0),
  ('premium_monthly','Premium Monthly',25000,'TZS','monthly',30,'Full access, billed every month','["Unlimited products","Multi-branch","POS & inventory","Marketplace listing","Instagram AI generator","Priority support"]'::jsonb,1),
  ('premium_yearly','Premium Yearly',250000,'TZS','yearly',30,'Save 2 months','["Everything in Monthly","2 months free","Advanced analytics","Custom branding"]'::jsonb,2)
ON CONFLICT (tier) DO NOTHING;
