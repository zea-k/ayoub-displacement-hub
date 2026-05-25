import { useEffect, useMemo, useRef, useState } from "react";
import { Link } from "react-router-dom";
import { motion } from "framer-motion";
import { useTranslation } from "react-i18next";
import { Heart, ShoppingCart, MessageCircle, Store, ArrowRight, Bookmark, Send } from "lucide-react";
import { useProductReactions } from "@/hooks/useProductReactions";
import { Input } from "@/components/ui/input";
import { CloudinaryImage } from "@/components/ui/CloudinaryImage";

export interface DiscoverProduct {
  id: string;
  name: string;
  selling_price: number;
  image_url: string | null;
  category: string | null;
  description: string | null;
  likes_count: number;
  comments_count: number;
  saves_count: number;
  owner_id: string;
  shop_slug?: string;
  shop_name?: string;
  shop_color?: string;
  created_at: string;
}

interface ProductFeedProps {
  products: DiscoverProduct[];
  loading: boolean;
}

export default function ProductFeed({ products, loading }: ProductFeedProps) {
  const { t } = useTranslation();
  const [visibleCount, setVisibleCount] = useState(6);
  const sentinelRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => setVisibleCount(6), [products]);

  useEffect(() => {
    if (!sentinelRef.current || loading) return;
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0]?.isIntersecting && visibleCount < products.length) {
          setVisibleCount((prev) => Math.min(prev + 6, products.length));
        }
      },
      { rootMargin: "200px" }
    );
    observer.observe(sentinelRef.current);
    return () => observer.disconnect();
  }, [loading, products.length, visibleCount]);

  const feed = useMemo(() => products.slice(0, visibleCount), [products, visibleCount]);

  return (
    <section className="px-0 pb-24">
      <div className="max-w-2xl mx-auto space-y-6 px-4">
        {loading && (
          <div className="space-y-6">
            {[...Array(3)].map((_, index) => (
              <div key={index} className="h-[460px] rounded-3xl bg-muted/40 animate-pulse" />
            ))}
          </div>
        )}

        {!loading && feed.length === 0 && (
          <div className="apple-card p-10 text-center">
            <Store className="mx-auto h-12 w-12 text-muted-foreground" />
            <h3 className="mt-4 text-lg font-semibold text-foreground">{t("market.noPostsYet")}</h3>
            <p className="mt-2 text-sm text-muted-foreground">{t("market.noPostsHint")}</p>
          </div>
        )}

        {feed.map((product, index) => (
          <FeedCard key={product.id} product={product} index={index} />
        ))}

        {!loading && visibleCount < products.length && <div ref={sentinelRef} className="h-8" />}
      </div>
    </section>
  );
}

function FeedCard({ product, index }: { product: DiscoverProduct; index: number }) {
  const { t } = useTranslation();
  const { counts, liked, saved, comments, toggleLike, toggleSave, postComment } = useProductReactions(product.id, {
    likes: product.likes_count,
    comments: product.comments_count,
    saves: product.saves_count,
  });
  const [showComments, setShowComments] = useState(false);
  const [draft, setDraft] = useState("");

  const onSubmitComment = (e: React.FormEvent) => {
    e.preventDefault();
    if (!draft.trim()) return;
    postComment(draft);
    setDraft("");
  };

  const accent = product.shop_color || "hsl(var(--primary))";

  return (
    <motion.article
      layout
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.35, ease: "easeOut", delay: Math.min(index * 0.03, 0.18) }}
      className="apple-card overflow-hidden"
    >
      {/* Header */}
      <div className="flex items-center justify-between gap-4 p-4">
        <div className="flex items-center gap-3 min-w-0">
          <div
            className="h-11 w-11 rounded-2xl flex items-center justify-center text-sm font-semibold shrink-0 ring-1 ring-border"
            style={{ backgroundColor: `${accent}1a`, color: accent }}
          >
            {product.shop_name?.charAt(0).toUpperCase() || "S"}
          </div>
          <div className="min-w-0">
            <p className="text-sm font-semibold text-foreground truncate">{product.shop_name || "ZEETOP Shop"}</p>
            <p className="text-xs text-muted-foreground truncate">{product.category || "Trending"}</p>
          </div>
        </div>
        <Link
          to={`/market/shop/${product.shop_slug}`}
          className="inline-flex items-center gap-1 rounded-full border border-border bg-background/60 px-3 py-1.5 text-xs text-foreground/80 transition hover:border-primary/40 hover:bg-primary/5 hover:text-primary shrink-0"
        >
          {t("market.visit")} <ArrowRight className="h-3.5 w-3.5" />
        </Link>
      </div>

      {/* Image */}
      <Link to={`/market/shop/${product.shop_slug}`} className="block bg-muted">
        {product.image_url ? (
          <CloudinaryImage
            src={product.image_url}
            alt={product.name}
            width={960}
            sizes="(max-width: 768px) 100vw, 640px"
            aspect="aspect-[4/5]"
            className="max-h-[520px]"
          />
        ) : (
          <div className="flex h-72 items-center justify-center bg-muted text-muted-foreground">
            <Store className="h-10 w-10" />
          </div>
        )}
      </Link>

      {/* Reaction bar */}
      <div className="flex items-center gap-4 px-4 pt-3">
        <button onClick={toggleLike} className="flex items-center gap-1 text-foreground/70 hover:text-rose-500 transition">
          <Heart className={`h-6 w-6 ${liked ? "fill-rose-500 text-rose-500" : ""}`} />
        </button>
        <button onClick={() => setShowComments((s) => !s)} className="flex items-center gap-1 text-foreground/70 hover:text-foreground transition">
          <MessageCircle className="h-6 w-6" />
        </button>
        <Link to={`/market/shop/${product.shop_slug}`} className="flex items-center gap-1 text-foreground/70 hover:text-primary transition">
          <ShoppingCart className="h-6 w-6" />
        </Link>
        <button onClick={toggleSave} className="ml-auto text-foreground/70 hover:text-accent transition">
          <Bookmark className={`h-6 w-6 ${saved ? "fill-accent text-accent" : ""}`} />
        </button>
      </div>

      <div className="px-4 pt-2 text-sm text-foreground">
        <span className="font-semibold">{counts.likes.toLocaleString()}</span>{" "}
        <span className="text-muted-foreground">{t("market.likes")}</span>
      </div>

      {/* Body */}
      <div className="px-4 py-2">
        <h3 className="text-lg font-semibold text-foreground">{product.name}</h3>
        <p className="text-primary font-bold mt-0.5">TZS {product.selling_price.toLocaleString()}</p>
        {product.description && (
          <p className="text-sm text-muted-foreground mt-2 line-clamp-3">{product.description}</p>
        )}
      </div>

      {/* Comments */}
      <div className="px-4 pb-4">
        <button
          onClick={() => setShowComments((s) => !s)}
          className="text-xs text-muted-foreground hover:text-foreground transition"
        >
          {showComments
            ? t("market.hideCommentsCount", { count: counts.comments })
            : t("market.viewCommentsCount", { count: counts.comments })}
        </button>

        {showComments && (
          <div className="mt-3 space-y-2">
            {comments.length === 0 ? (
              <p className="text-xs text-muted-foreground/70">{t("market.beFirstComment")}</p>
            ) : (
              comments.slice(0, 5).map((c) => (
                <div key={c.id} className="text-sm text-foreground/80">
                  <span className="font-semibold text-foreground mr-2">{c.user_name}</span>
                  {c.comment_text}
                </div>
              ))
            )}
            <form onSubmit={onSubmitComment} className="flex items-center gap-2 pt-2">
              <Input
                value={draft}
                onChange={(e) => setDraft(e.target.value)}
                placeholder={t("market.addComment")}
                className="bg-background border-border text-foreground text-sm h-9"
              />
              <button type="submit" className="text-primary hover:text-primary/80 transition">
                <Send className="h-4 w-4" />
              </button>
            </form>
          </div>
        )}
      </div>
    </motion.article>
  );
}
