import { useEffect, useState, useMemo, useCallback } from "react";
import { useParams } from "react-router-dom";
import { supabase } from "@/lib/supabase";
import { toast } from "sonner";
import { PublicStoreHeader } from "@/components/public-store/PublicStoreHeader";
import { PublicStoreSearchBar } from "@/components/public-store/PublicStoreSearchBar";
import { PublicStoreProductGrid } from "@/components/public-store/PublicStoreProductGrid";
import { PublicStoreBanner } from "@/components/public-store/PublicStoreBanner";
import { PublicStoreFeatured } from "@/components/public-store/PublicStoreFeatured";
import { PublicStoreProductDetail } from "@/components/public-store/PublicStoreProductDetail";
import { PublicStoreCartButton, PublicStoreCartDrawer } from "@/components/public-store/PublicStoreCart";
import type { CartItem } from "@/components/public-store/PublicStoreCart";
import { PublicStoreCheckoutDialog } from "@/components/public-store/PublicStoreCheckoutDialog";
import { PublicStoreFooter } from "@/components/public-store/PublicStoreFooter";
import { PublicStoreLoading } from "@/components/public-store/PublicStoreLoading";
import { PublicStoreNotFound } from "@/components/public-store/PublicStoreNotFound";
import { PublicStoreOrderTracking } from "@/components/public-store/PublicStoreOrderTracking";
import { Sheet, SheetContent } from "@/components/ui/sheet";
import { motion } from "framer-motion";
import ShopRouteMap from "@/components/map/ShopRouteMap";

export interface StoreSettings {
  owner_id: string;
  business_name: string;
  logo_url: string | null;
  theme: string;
  theme_color: string;
  whatsapp_number: string | null;
  contact_email: string | null;
  contact_phone: string | null;
  description: string | null;
  latitude: number | null;
  longitude: number | null;
}

export interface PublicProduct {
  id: string;
  name: string;
  description: string | null;
  selling_price: number;
  stock: number;
  category: string;
  image_url: string | null;
  featured: boolean;
}

export interface PromoBanner {
  id: string;
  title: string;
  subtitle: string | null;
  image_url: string | null;
  bg_color: string;
}

export default function PublicStorePage() {
  const { slug } = useParams<{ slug: string }>();
  const [store, setStore] = useState<StoreSettings | null>(null);
  const [products, setProducts] = useState<PublicProduct[]>([]);
  const [loading, setLoading] = useState(true);
  const [notFound, setNotFound] = useState(false);
  const [banners, setBanners] = useState<PromoBanner[]>([]);

  // Search & filter
  const [searchQuery, setSearchQuery] = useState("");
  const [selectedCategory, setSelectedCategory] = useState("");
  const [viewMode, setViewMode] = useState<"grid" | "list">("grid");

  // Cart
  const [cartItems, setCartItems] = useState<CartItem[]>([]);
  const [cartOpen, setCartOpen] = useState(false);

  // Product detail
  const [detailProduct, setDetailProduct] = useState<PublicProduct | null>(null);
  const [detailOpen, setDetailOpen] = useState(false);

  // Checkout
  const [checkoutOpen, setCheckoutOpen] = useState(false);
  const [checkoutForm, setCheckoutForm] = useState({ customer_name: "", phone: "" });
  const [submitting, setSubmitting] = useState(false);

  // Single order (direct order)
  const [orderOpen, setOrderOpen] = useState(false);
  const [orderProduct, setOrderProduct] = useState<PublicProduct | null>(null);
  const [orderForm, setOrderForm] = useState({ customer_name: "", phone: "", quantity: 1 });
  
  // Tracking view
  const [showTracking, setShowTracking] = useState(false);

  useEffect(() => {
    const fetchStore = async () => {
      setLoading(true);
      const { data: settings } = await supabase
        .from("public_settings")
        .select("owner_id, business_name, logo_url, theme, theme_color, whatsapp_number, contact_email, contact_phone, description, latitude, longitude")
        .eq("slug", slug)
        .eq("is_public_enabled", true)
        .maybeSingle();

      if (!settings) { setNotFound(true); setLoading(false); return; }
      // Brand override: align every public store with the ZEETOP landing page identity
      // (light Apple-style theme + violet accent) regardless of per-store settings.
      const branded = {
        ...settings,
        theme: "light",
        theme_color: "#7c3aed", // violet-600
      } as StoreSettings;
      setStore(branded);

      const { data: prods } = await supabase
        .from("products")
        .select("id, name, description, selling_price, stock, category, image_url, featured")
        .eq("owner_id", settings.owner_id)
        .eq("public_visible", true)
        .gt("stock", 0)
        .order("name");

      setProducts((prods as PublicProduct[]) || []);

      // Fetch banners
      const { data: bannerData } = await supabase
        .from("promotional_banners")
        .select("id, title, subtitle, image_url, bg_color")
        .eq("owner_id", settings.owner_id)
        .eq("is_active", true)
        .order("position");

      setBanners((bannerData as PromoBanner[]) || []);
      setLoading(false);
    };
    if (slug) fetchStore();
  }, [slug]);

  // Categories
  const categories = useMemo(() => {
    const cats = new Set(products.map((p) => p.category).filter(Boolean));
    return Array.from(cats).sort();
  }, [products]);

  // Filtered products
  const filteredProducts = useMemo(() => {
    return products.filter((p) => {
      const matchesSearch = !searchQuery || p.name.toLowerCase().includes(searchQuery.toLowerCase()) || p.description?.toLowerCase().includes(searchQuery.toLowerCase());
      const matchesCat = !selectedCategory || p.category === selectedCategory;
      return matchesSearch && matchesCat;
    });
  }, [products, searchQuery, selectedCategory]);

  // Featured products
  const featuredProducts = useMemo(() => {
    return products.filter((p) => p.featured);
  }, [products]);

  // Cart actions
  const addToCart = useCallback((product: PublicProduct) => {
    setCartItems((prev) => {
      const existing = prev.find((i) => i.product.id === product.id);
      if (existing) {
        toast.success(`Updated ${product.name} quantity`);
        return prev.map((i) =>
          i.product.id === product.id ? { ...i, quantity: Math.min(i.quantity + 1, product.stock) } : i
        );
      }
      toast.success(`${product.name} added to cart`);
      return [...prev, { product, quantity: 1 }];
    });
  }, []);

  const updateCartQuantity = useCallback((productId: string, qty: number) => {
    setCartItems((prev) => prev.map((i) => (i.product.id === productId ? { ...i, quantity: qty } : i)));
  }, []);

  const removeFromCart = useCallback((productId: string) => {
    setCartItems((prev) => prev.filter((i) => i.product.id !== productId));
  }, []);

  // WhatsApp
  const openWhatsApp = (product: PublicProduct) => {
    if (!store?.whatsapp_number) { toast.error("WhatsApp not configured"); return; }
    const num = store.whatsapp_number.replace(/[^0-9]/g, "");
    const msg = encodeURIComponent(`Hello, I want to order ${product.name}. Price: TZS ${product.selling_price.toLocaleString()}`);
    window.open(`https://wa.me/${num}?text=${msg}`, "_blank");
  };

  // Direct order
  const openOrderForm = (product: PublicProduct) => {
    setOrderProduct(product);
    setOrderForm({ customer_name: "", phone: "", quantity: 1 });
    setOrderOpen(true);
  };

  const sendWhatsAppNotification = (customerName: string, items: { name: string; qty: number; price: number }[]) => {
    if (!store?.whatsapp_number) return;
    const num = store.whatsapp_number.replace(/[^0-9]/g, "");
    const itemLines = items.map(i => `• ${i.name} x${i.qty} — TZS ${(i.price * i.qty).toLocaleString()}`).join("\n");
    const total = items.reduce((s, i) => s + i.price * i.qty, 0);
    const msg = encodeURIComponent(
      `🛒 New Order!\n\nCustomer: ${customerName}\n\n${itemLines}\n\nTotal: TZS ${total.toLocaleString()}\n\nPlease confirm my order. Thank you!`
    );
    window.open(`https://wa.me/${num}?text=${msg}`, "_blank");
  };

  const submitDirectOrder = async () => {
    if (!orderProduct || !store) return;
    if (!orderForm.customer_name.trim()) { toast.error("Name is required"); return; }
    if (!orderForm.phone.trim()) { toast.error("Phone is required"); return; }
    setSubmitting(true);
    const { error } = await supabase.from("public_orders").insert({
      owner_id: store.owner_id,
      product_id: orderProduct.id,
      customer_name: orderForm.customer_name.trim(),
      phone: orderForm.phone.trim(),
      quantity: orderForm.quantity,
    });
    setSubmitting(false);
    if (error) { toast.error("Failed to place order"); return; }
    toast.success("Order placed successfully!");
    setOrderOpen(false);
    if (store.whatsapp_number) {
      sendWhatsAppNotification(orderForm.customer_name.trim(), [
        { name: orderProduct.name, qty: orderForm.quantity, price: orderProduct.selling_price },
      ]);
    }
  };

  // Cart checkout
  const submitCartCheckout = async () => {
    if (!store || cartItems.length === 0) return;
    if (!checkoutForm.customer_name.trim()) { toast.error("Name is required"); return; }
    if (!checkoutForm.phone.trim()) { toast.error("Phone is required"); return; }
    setSubmitting(true);

    const inserts = cartItems.map((item) => ({
      owner_id: store.owner_id,
      product_id: item.product.id,
      customer_name: checkoutForm.customer_name.trim(),
      phone: checkoutForm.phone.trim(),
      quantity: item.quantity,
    }));

    const { error } = await supabase.from("public_orders").insert(inserts);
    setSubmitting(false);
    if (error) { toast.error("Failed to place order"); return; }
    toast.success(`${cartItems.length} item(s) ordered successfully!`);
    if (store.whatsapp_number) {
      sendWhatsAppNotification(
        checkoutForm.customer_name.trim(),
        cartItems.map(i => ({ name: i.product.name, qty: i.quantity, price: i.product.selling_price }))
      );
    }
    setCartItems([]);
    setCheckoutOpen(false);
    setCartOpen(false);
  };

  if (loading) return <PublicStoreLoading />;
  if (notFound || !store) return <PublicStoreNotFound />;

  const isDark = store.theme === "dark";
  const cartCount = cartItems.reduce((s, i) => s + i.quantity, 0);

  if (showTracking) {
    return <PublicStoreOrderTracking store={store} isDark={isDark} onBack={() => setShowTracking(false)} />;
  }

  return (
    <div className="min-h-screen bg-background p-2 sm:p-3 lg:p-4">
      <div className="relative rounded-[1.75rem] p-[1.5px] bg-[conic-gradient(from_140deg_at_50%_50%,hsl(var(--primary)/0.55),hsl(var(--accent)/0.45),hsl(var(--primary)/0.15),hsl(var(--accent)/0.5),hsl(var(--primary)/0.55))] shadow-[0_30px_80px_-30px_hsl(var(--primary)/0.45),0_10px_40px_-20px_hsl(var(--accent)/0.35)]">
        <div className="relative overflow-hidden rounded-[1.65rem] ring-1 ring-white/10 bg-gradient-to-br from-background via-background/95 to-background/90 text-foreground">

      {/* Premium Background Effects */}
      <div className="fixed inset-0 pointer-events-none overflow-hidden">
        <div className="absolute -top-40 -right-40 w-[600px] h-[600px] rounded-full opacity-20 blur-[150px] bg-gradient-to-br from-primary/30 to-accent/20" />
        <div className="absolute -bottom-40 -left-40 w-[500px] h-[500px] rounded-full opacity-20 blur-[120px] bg-gradient-to-br from-accent/30 to-primary/20" />
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[800px] h-[800px] rounded-full opacity-10 blur-[200px] bg-gradient-to-br from-primary/20 via-accent/10 to-transparent" />
      </div>

      <div className="relative z-10">
        <motion.div
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
        >
          <PublicStoreHeader store={store} isDark={isDark} productCount={products.length} onTrackOrder={() => setShowTracking(true)} />
        </motion.div>

        {/* Hero map - shop location */}
        <div className="max-w-6xl mx-auto px-4 sm:px-6 pt-6">
          <ShopRouteMap
            shopName={store.business_name}
            latitude={store.latitude}
            longitude={store.longitude}
          />
        </div>

        {/* Promotional Banners */}
        <PublicStoreBanner banners={banners} isDark={isDark} themeColor={store.theme_color} />


        {/* Featured Products */}
        <PublicStoreFeatured
          products={featuredProducts}
          store={store}
          isDark={isDark}
          onAddToCart={addToCart}
          onViewProduct={(p) => { setDetailProduct(p); setDetailOpen(true); }}
        />

        <PublicStoreSearchBar
          categories={categories}
          selectedCategory={selectedCategory}
          onCategoryChange={setSelectedCategory}
          searchQuery={searchQuery}
          onSearchChange={setSearchQuery}
          viewMode={viewMode}
          onViewModeChange={setViewMode}
          store={store}
          isDark={isDark}
          totalProducts={products.length}
        />

        <PublicStoreProductGrid
          products={filteredProducts}
          store={store}
          isDark={isDark}
          viewMode={viewMode}
          onWhatsApp={openWhatsApp}
          onAddToCart={addToCart}
          onViewProduct={(p) => { setDetailProduct(p); setDetailOpen(true); }}
        />




        <PublicStoreFooter store={store} isDark={isDark} />
      </div>

      {/* Floating cart button */}
      <PublicStoreCartButton itemCount={cartCount} onClick={() => setCartOpen(true)} store={store} />

      {/* Cart drawer */}
      <Sheet open={cartOpen} onOpenChange={setCartOpen}>
        <SheetContent side="right" className={`p-0 w-full sm:max-w-md border-0 ${isDark ? "bg-[#12121a] text-gray-100" : "bg-white text-gray-900"}`}>
          <PublicStoreCartDrawer
            items={cartItems}
            onUpdateQuantity={updateCartQuantity}
            onRemove={removeFromCart}
            onCheckout={() => { setCheckoutForm({ customer_name: "", phone: "" }); setCheckoutOpen(true); }}
            store={store}
            isDark={isDark}
          />
        </SheetContent>
      </Sheet>

      {/* Product detail modal */}
      <PublicStoreProductDetail
        product={detailProduct}
        open={detailOpen}
        onOpenChange={setDetailOpen}
        store={store}
        isDark={isDark}
        onAddToCart={addToCart}
        onWhatsApp={openWhatsApp}
        onOrderNow={openOrderForm}
      />

      {/* Checkout dialog (cart) */}
      <PublicStoreCheckoutDialog
        open={checkoutOpen}
        onOpenChange={setCheckoutOpen}
        items={cartItems}
        store={store}
        isDark={isDark}
        form={checkoutForm}
        setForm={setCheckoutForm}
        onSubmit={submitCartCheckout}
        submitting={submitting}
      />

      {/* Direct order dialog (single product - kept for backward compat) */}
      {orderOpen && orderProduct && (
        <PublicStoreOrderDialog_Legacy
          open={orderOpen}
          onOpenChange={setOrderOpen}
          product={orderProduct}
          store={store}
          isDark={isDark}
          form={orderForm}
          setForm={setOrderForm}
          onSubmit={submitDirectOrder}
          submitting={submitting}
        />
      )}
        </div>
      </div>
    </div>
  );

}

// Keep the old order dialog for direct "Order Now" from product detail
import { PublicStoreOrderDialog as PublicStoreOrderDialog_Legacy } from "@/components/public-store/PublicStoreOrderDialog";
