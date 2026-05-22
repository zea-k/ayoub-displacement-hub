export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  public: {
    Tables: {
      activity_logs: {
        Row: {
          action_type: string
          created_at: string
          description: string
          id: string
          owner_id: string
          related_id: string | null
          user_id: string
        }
        Insert: {
          action_type: string
          created_at?: string
          description: string
          id?: string
          owner_id?: string
          related_id?: string | null
          user_id?: string
        }
        Update: {
          action_type?: string
          created_at?: string
          description?: string
          id?: string
          owner_id?: string
          related_id?: string | null
          user_id?: string
        }
        Relationships: []
      }
      categories: {
        Row: {
          created_at: string
          icon: string | null
          id: string
          name: string
          slug: string
          sort_order: number
        }
        Insert: {
          created_at?: string
          icon?: string | null
          id?: string
          name: string
          slug: string
          sort_order?: number
        }
        Update: {
          created_at?: string
          icon?: string | null
          id?: string
          name?: string
          slug?: string
          sort_order?: number
        }
        Relationships: []
      }
      day_closings: {
        Row: {
          bank_total: number
          cash_total: number
          closed_at: string
          date: string
          id: string
          mobile_money_total: number
          net_profit: number
          owner_id: string
          total_discounts: number
          total_expenses: number
          total_profit: number
          total_sales: number
          total_transactions: number
        }
        Insert: {
          bank_total?: number
          cash_total?: number
          closed_at?: string
          date?: string
          id?: string
          mobile_money_total?: number
          net_profit?: number
          owner_id?: string
          total_discounts?: number
          total_expenses?: number
          total_profit?: number
          total_sales?: number
          total_transactions?: number
        }
        Update: {
          bank_total?: number
          cash_total?: number
          closed_at?: string
          date?: string
          id?: string
          mobile_money_total?: number
          net_profit?: number
          owner_id?: string
          total_discounts?: number
          total_expenses?: number
          total_profit?: number
          total_sales?: number
          total_transactions?: number
        }
        Relationships: []
      }
      expenses: {
        Row: {
          amount: number
          category: string
          created_at: string
          date: string
          id: string
          name: string
          notes: string | null
          owner_id: string
        }
        Insert: {
          amount?: number
          category?: string
          created_at?: string
          date?: string
          id?: string
          name: string
          notes?: string | null
          owner_id?: string
        }
        Update: {
          amount?: number
          category?: string
          created_at?: string
          date?: string
          id?: string
          name?: string
          notes?: string | null
          owner_id?: string
        }
        Relationships: []
      }
      instagram_content_history: {
        Row: {
          caption: string
          created_at: string
          generated_image_url: string | null
          hashtags: string
          id: string
          owner_id: string
          product_id: string
          style_type: string
        }
        Insert: {
          caption: string
          created_at?: string
          generated_image_url?: string | null
          hashtags: string
          id?: string
          owner_id?: string
          product_id: string
          style_type?: string
        }
        Update: {
          caption?: string
          created_at?: string
          generated_image_url?: string | null
          hashtags?: string
          id?: string
          owner_id?: string
          product_id?: string
          style_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "instagram_content_history_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      payment_methods: {
        Row: {
          account_identifier: string
          created_at: string | null
          id: string
          is_default: boolean | null
          payment_type: string
          provider: string
          updated_at: string | null
          user_id: string
          verified: boolean | null
        }
        Insert: {
          account_identifier: string
          created_at?: string | null
          id?: string
          is_default?: boolean | null
          payment_type: string
          provider: string
          updated_at?: string | null
          user_id: string
          verified?: boolean | null
        }
        Update: {
          account_identifier?: string
          created_at?: string | null
          id?: string
          is_default?: boolean | null
          payment_type?: string
          provider?: string
          updated_at?: string | null
          user_id?: string
          verified?: boolean | null
        }
        Relationships: []
      }
      pos_sales: {
        Row: {
          amount_received: number
          balance_returned: number
          created_at: string
          final_total: number
          id: string
          notes: string | null
          owner_id: string
          payment_method: string
          receipt_number: string
          sale_discount_amount: number
          sale_discount_type: string | null
          sale_discount_value: number
          subtotal: number
          total_item_discount: number
          total_profit: number
        }
        Insert: {
          amount_received?: number
          balance_returned?: number
          created_at?: string
          final_total?: number
          id?: string
          notes?: string | null
          owner_id?: string
          payment_method?: string
          receipt_number: string
          sale_discount_amount?: number
          sale_discount_type?: string | null
          sale_discount_value?: number
          subtotal?: number
          total_item_discount?: number
          total_profit?: number
        }
        Update: {
          amount_received?: number
          balance_returned?: number
          created_at?: string
          final_total?: number
          id?: string
          notes?: string | null
          owner_id?: string
          payment_method?: string
          receipt_number?: string
          sale_discount_amount?: number
          sale_discount_type?: string | null
          sale_discount_value?: number
          subtotal?: number
          total_item_discount?: number
          total_profit?: number
        }
        Relationships: []
      }
      product_stories: {
        Row: {
          created_at: string | null
          id: string
          image_url: string | null
          owner_id: string
          product_id: string
          product_name: string
          published_platforms: string[] | null
          status: string
          story: string
          title: string
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          image_url?: string | null
          owner_id: string
          product_id: string
          product_name: string
          published_platforms?: string[] | null
          status?: string
          story: string
          title: string
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          image_url?: string | null
          owner_id?: string
          product_id?: string
          product_name?: string
          published_platforms?: string[] | null
          status?: string
          story?: string
          title?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "product_stories_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      products: {
        Row: {
          buying_price: number
          category: string | null
          comments_count: number
          created_at: string
          description: string | null
          featured: boolean
          id: string
          image_url: string | null
          likes_count: number
          low_stock_alert: number
          name: string
          owner_id: string
          public_visible: boolean
          saves_count: number
          selling_price: number
          stock: number
          updated_at: string
        }
        Insert: {
          buying_price?: number
          category?: string | null
          comments_count?: number
          created_at?: string
          description?: string | null
          featured?: boolean
          id?: string
          image_url?: string | null
          likes_count?: number
          low_stock_alert?: number
          name: string
          owner_id?: string
          public_visible?: boolean
          saves_count?: number
          selling_price?: number
          stock?: number
          updated_at?: string
        }
        Update: {
          buying_price?: number
          category?: string | null
          comments_count?: number
          created_at?: string
          description?: string | null
          featured?: boolean
          id?: string
          image_url?: string | null
          likes_count?: number
          low_stock_alert?: number
          name?: string
          owner_id?: string
          public_visible?: boolean
          saves_count?: number
          selling_price?: number
          stock?: number
          updated_at?: string
        }
        Relationships: []
      }
      profiles: {
        Row: {
          avatar_url: string | null
          created_at: string
          email: string
          id: string
          name: string
          phone: string | null
          updated_at: string
          user_id: string
          whatsapp: string | null
        }
        Insert: {
          avatar_url?: string | null
          created_at?: string
          email?: string
          id?: string
          name?: string
          phone?: string | null
          updated_at?: string
          user_id: string
          whatsapp?: string | null
        }
        Update: {
          avatar_url?: string | null
          created_at?: string
          email?: string
          id?: string
          name?: string
          phone?: string | null
          updated_at?: string
          user_id?: string
          whatsapp?: string | null
        }
        Relationships: []
      }
      promotional_banners: {
        Row: {
          bg_color: string
          created_at: string
          id: string
          image_url: string | null
          is_active: boolean
          owner_id: string
          position: number
          subtitle: string | null
          title: string
          updated_at: string
        }
        Insert: {
          bg_color?: string
          created_at?: string
          id?: string
          image_url?: string | null
          is_active?: boolean
          owner_id?: string
          position?: number
          subtitle?: string | null
          title?: string
          updated_at?: string
        }
        Update: {
          bg_color?: string
          created_at?: string
          id?: string
          image_url?: string | null
          is_active?: boolean
          owner_id?: string
          position?: number
          subtitle?: string | null
          title?: string
          updated_at?: string
        }
        Relationships: []
      }
      public_orders: {
        Row: {
          created_at: string
          customer_name: string
          id: string
          notes: string | null
          owner_id: string
          phone: string
          product_id: string
          quantity: number
          status: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          customer_name: string
          id?: string
          notes?: string | null
          owner_id: string
          phone: string
          product_id: string
          quantity?: number
          status?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          customer_name?: string
          id?: string
          notes?: string | null
          owner_id?: string
          phone?: string
          product_id?: string
          quantity?: number
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "public_orders_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      public_settings: {
        Row: {
          address: string | null
          business_name: string
          category: string | null
          category_id: string | null
          contact_email: string | null
          contact_phone: string | null
          created_at: string
          description: string | null
          engagement_score: number
          follower_count: number
          id: string
          is_featured: boolean
          is_listed: boolean
          is_public_enabled: boolean
          latitude: number | null
          logo_url: string | null
          longitude: number | null
          owner_id: string
          slug: string
          theme: string
          theme_color: string
          updated_at: string
          whatsapp_number: string | null
        }
        Insert: {
          address?: string | null
          business_name?: string
          category?: string | null
          category_id?: string | null
          contact_email?: string | null
          contact_phone?: string | null
          created_at?: string
          description?: string | null
          engagement_score?: number
          follower_count?: number
          id?: string
          is_featured?: boolean
          is_listed?: boolean
          is_public_enabled?: boolean
          latitude?: number | null
          logo_url?: string | null
          longitude?: number | null
          owner_id: string
          slug?: string
          theme?: string
          theme_color?: string
          updated_at?: string
          whatsapp_number?: string | null
        }
        Update: {
          address?: string | null
          business_name?: string
          category?: string | null
          category_id?: string | null
          contact_email?: string | null
          contact_phone?: string | null
          created_at?: string
          description?: string | null
          engagement_score?: number
          follower_count?: number
          id?: string
          is_featured?: boolean
          is_listed?: boolean
          is_public_enabled?: boolean
          latitude?: number | null
          logo_url?: string | null
          longitude?: number | null
          owner_id?: string
          slug?: string
          theme?: string
          theme_color?: string
          updated_at?: string
          whatsapp_number?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "public_settings_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "categories"
            referencedColumns: ["id"]
          },
        ]
      }
      purchases: {
        Row: {
          buying_price: number
          created_at: string
          date: string
          id: string
          notes: string | null
          owner_id: string
          product_id: string
          quantity: number
          supplier_id: string | null
          total_cost: number
        }
        Insert: {
          buying_price?: number
          created_at?: string
          date?: string
          id?: string
          notes?: string | null
          owner_id?: string
          product_id: string
          quantity?: number
          supplier_id?: string | null
          total_cost?: number
        }
        Update: {
          buying_price?: number
          created_at?: string
          date?: string
          id?: string
          notes?: string | null
          owner_id?: string
          product_id?: string
          quantity?: number
          supplier_id?: string | null
          total_cost?: number
        }
        Relationships: [
          {
            foreignKeyName: "purchases_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "purchases_supplier_id_fkey"
            columns: ["supplier_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["id"]
          },
        ]
      }
      refunds: {
        Row: {
          created_at: string
          id: string
          items: Json | null
          owner_id: string
          reason: string | null
          refund_amount: number
          sale_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          items?: Json | null
          owner_id?: string
          reason?: string | null
          refund_amount?: number
          sale_id: string
        }
        Update: {
          created_at?: string
          id?: string
          items?: Json | null
          owner_id?: string
          reason?: string | null
          refund_amount?: number
          sale_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "refunds_sale_id_fkey"
            columns: ["sale_id"]
            isOneToOne: false
            referencedRelation: "pos_sales"
            referencedColumns: ["id"]
          },
        ]
      }
      sale_items: {
        Row: {
          buying_price: number
          discount_amount: number
          discount_type: string | null
          discount_value: number
          id: string
          item_subtotal: number
          product_id: string
          product_name: string
          profit: number
          quantity: number
          sale_id: string
          unit_price: number
        }
        Insert: {
          buying_price?: number
          discount_amount?: number
          discount_type?: string | null
          discount_value?: number
          id?: string
          item_subtotal?: number
          product_id: string
          product_name: string
          profit?: number
          quantity?: number
          sale_id: string
          unit_price?: number
        }
        Update: {
          buying_price?: number
          discount_amount?: number
          discount_type?: string | null
          discount_value?: number
          id?: string
          item_subtotal?: number
          product_id?: string
          product_name?: string
          profit?: number
          quantity?: number
          sale_id?: string
          unit_price?: number
        }
        Relationships: [
          {
            foreignKeyName: "sale_items_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "sale_items_sale_id_fkey"
            columns: ["sale_id"]
            isOneToOne: false
            referencedRelation: "pos_sales"
            referencedColumns: ["id"]
          },
        ]
      }
      sales: {
        Row: {
          buying_price: number
          created_at: string
          id: string
          notes: string | null
          owner_id: string
          product_id: string
          profit: number | null
          quantity: number
          selling_price: number
          total_sale: number | null
        }
        Insert: {
          buying_price?: number
          created_at?: string
          id?: string
          notes?: string | null
          owner_id?: string
          product_id: string
          profit?: number | null
          quantity?: number
          selling_price?: number
          total_sale?: number | null
        }
        Update: {
          buying_price?: number
          created_at?: string
          id?: string
          notes?: string | null
          owner_id?: string
          product_id?: string
          profit?: number | null
          quantity?: number
          selling_price?: number
          total_sale?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "sales_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      stock_in: {
        Row: {
          buying_price: number
          created_at: string
          id: string
          notes: string | null
          owner_id: string
          product_id: string
          quantity: number
          selling_price: number
          total_cost: number | null
        }
        Insert: {
          buying_price?: number
          created_at?: string
          id?: string
          notes?: string | null
          owner_id?: string
          product_id: string
          quantity?: number
          selling_price?: number
          total_cost?: number | null
        }
        Update: {
          buying_price?: number
          created_at?: string
          id?: string
          notes?: string | null
          owner_id?: string
          product_id?: string
          quantity?: number
          selling_price?: number
          total_cost?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "stock_in_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      subscription_plans: {
        Row: {
          billing_period: string
          created_at: string
          currency: string
          description: string | null
          features: Json
          id: string
          name: string
          price: number
          sort_order: number
          tier: string
          trial_days: number
          updated_at: string
        }
        Insert: {
          billing_period?: string
          created_at?: string
          currency?: string
          description?: string | null
          features?: Json
          id?: string
          name: string
          price?: number
          sort_order?: number
          tier: string
          trial_days?: number
          updated_at?: string
        }
        Update: {
          billing_period?: string
          created_at?: string
          currency?: string
          description?: string | null
          features?: Json
          id?: string
          name?: string
          price?: number
          sort_order?: number
          tier?: string
          trial_days?: number
          updated_at?: string
        }
        Relationships: []
      }
      suppliers: {
        Row: {
          address: string | null
          created_at: string
          email: string | null
          id: string
          name: string
          notes: string | null
          owner_id: string
          phone: string | null
        }
        Insert: {
          address?: string | null
          created_at?: string
          email?: string | null
          id?: string
          name: string
          notes?: string | null
          owner_id?: string
          phone?: string | null
        }
        Update: {
          address?: string | null
          created_at?: string
          email?: string | null
          id?: string
          name?: string
          notes?: string | null
          owner_id?: string
          phone?: string | null
        }
        Relationships: []
      }
      user_activity: {
        Row: {
          activity_type: string
          created_at: string
          duration_seconds: number | null
          id: string
          target_category: string | null
          target_id: string
          user_id: string
        }
        Insert: {
          activity_type: string
          created_at?: string
          duration_seconds?: number | null
          id?: string
          target_category?: string | null
          target_id: string
          user_id: string
        }
        Update: {
          activity_type?: string
          created_at?: string
          duration_seconds?: number | null
          id?: string
          target_category?: string | null
          target_id?: string
          user_id?: string
        }
        Relationships: []
      }
      user_branches: {
        Row: {
          account_id: string
          branch_name: string
          contact_info: Json | null
          created_at: string | null
          id: string
          is_main_branch: boolean | null
          location: string | null
          manager_id: string | null
          settings: Json | null
          updated_at: string | null
        }
        Insert: {
          account_id: string
          branch_name: string
          contact_info?: Json | null
          created_at?: string | null
          id?: string
          is_main_branch?: boolean | null
          location?: string | null
          manager_id?: string | null
          settings?: Json | null
          updated_at?: string | null
        }
        Update: {
          account_id?: string
          branch_name?: string
          contact_info?: Json | null
          created_at?: string | null
          id?: string
          is_main_branch?: boolean | null
          location?: string | null
          manager_id?: string | null
          settings?: Json | null
          updated_at?: string | null
        }
        Relationships: []
      }
      user_profiles: {
        Row: {
          created_at: string | null
          id: string
          subscription_status: string | null
          subscription_tier: string | null
          updated_at: string | null
          user_type: string
        }
        Insert: {
          created_at?: string | null
          id: string
          subscription_status?: string | null
          subscription_tier?: string | null
          updated_at?: string | null
          user_type?: string
        }
        Update: {
          created_at?: string | null
          id?: string
          subscription_status?: string | null
          subscription_tier?: string | null
          updated_at?: string | null
          user_type?: string
        }
        Relationships: []
      }
      user_roles: {
        Row: {
          created_at: string
          granted_by: string | null
          id: string
          role: Database["public"]["Enums"]["app_role_v2"]
          user_id: string
        }
        Insert: {
          created_at?: string
          granted_by?: string | null
          id?: string
          role: Database["public"]["Enums"]["app_role_v2"]
          user_id: string
        }
        Update: {
          created_at?: string
          granted_by?: string | null
          id?: string
          role?: Database["public"]["Enums"]["app_role_v2"]
          user_id?: string
        }
        Relationships: []
      }
      user_subscriptions: {
        Row: {
          auto_renew: boolean | null
          created_at: string | null
          ends_at: string | null
          id: string
          payment_method_id: string | null
          plan_id: string
          started_at: string | null
          status: string
          subscription_tier: string
          trial_ends_at: string | null
          trial_started_at: string | null
          updated_at: string | null
          user_id: string
        }
        Insert: {
          auto_renew?: boolean | null
          created_at?: string | null
          ends_at?: string | null
          id?: string
          payment_method_id?: string | null
          plan_id: string
          started_at?: string | null
          status?: string
          subscription_tier: string
          trial_ends_at?: string | null
          trial_started_at?: string | null
          updated_at?: string | null
          user_id: string
        }
        Update: {
          auto_renew?: boolean | null
          created_at?: string | null
          ends_at?: string | null
          id?: string
          payment_method_id?: string | null
          plan_id?: string
          started_at?: string | null
          status?: string
          subscription_tier?: string
          trial_ends_at?: string | null
          trial_started_at?: string | null
          updated_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_subscriptions_plan_id_fkey"
            columns: ["plan_id"]
            isOneToOne: false
            referencedRelation: "subscription_plans"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      generate_receipt_number: { Args: { _owner_id: string }; Returns: string }
      has_role: {
        Args: {
          _role: Database["public"]["Enums"]["app_role_v2"]
          _user_id: string
        }
        Returns: boolean
      }
    }
    Enums: {
      app_role: "seller" | "customer"
      app_role_v2: "owner" | "cashier"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      app_role: ["seller", "customer"],
      app_role_v2: ["owner", "cashier"],
    },
  },
} as const
