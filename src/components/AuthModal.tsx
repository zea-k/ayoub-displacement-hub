import { useState } from "react";
import { useTranslation } from "react-i18next";
import { Dialog, DialogContent } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useAuth } from "@/contexts/AuthContext";
import { toast } from "sonner";
import { useNavigate } from "react-router-dom";
import { Eye, EyeOff, ArrowLeft } from "lucide-react";
import zeetopLogo from "@/assets/zeetop-logo.png";
import { normalizePhone } from "@/lib/phone-auth";
import { supabase } from "@/integrations/supabase/client";
import type { UserType } from "@/types/subscription";

interface AuthModalProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  defaultView?: "login" | "register";
}

type View = "login" | "register" | "forgot";

export default function AuthModal({ open, onOpenChange, defaultView = "login" }: AuthModalProps) {
  const { t } = useTranslation();
  const [view, setView] = useState<View>(defaultView);
  const [registerStep, setRegisterStep] = useState<"type" | "details">("type");
  const [name, setName] = useState("");
  const [phone, setPhone] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [userType, setUserType] = useState<UserType>("buyer");
  const [loading, setLoading] = useState(false);
  const { signIn, signUp } = useAuth();
  const navigate = useNavigate();

  const resetState = () => {
    setName(""); setPhone(""); setPassword(""); setShowPassword(false);
    setUserType("buyer"); setRegisterStep("type");
  };

  const handleOpenChange = (val: boolean) => {
    if (val) {
      setView(defaultView);
      setRegisterStep("type");
    }
    onOpenChange(val);
    if (!val) resetState();
  };

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!normalizePhone(phone)) {
      toast.error(t("auth.invalidPhone"));
      return;
    }
    setLoading(true);
    const { error } = await signIn(phone, password);
    setLoading(false);
    if (error) {
      toast.error(error.message);
    } else {
      toast.success(t("auth.welcomeBackToast"));
      handleOpenChange(false);
      navigate("/", { replace: true });
    }
  };

  const handleRegisterTypeSelection = (type: UserType) => {
    setUserType(type);
    setRegisterStep("details");
  };

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!normalizePhone(phone)) {
      toast.error(t("auth.invalidPhone"));
      return;
    }
    if (!password) return;
    setLoading(true);
    const { error } = await signUp(phone, password, name, userType);
    setLoading(false);
    if (error) {
      toast.error(error.message);
    } else {
      toast.success(t("auth.accountCreatedToast"));
      handleOpenChange(false);
      navigate(userType === "buyer" ? "/market" : "/", { replace: true });
    }
  };

  const handleForgotPassword = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) {
      toast.error("Weka jina lako kamili");
      return;
    }
    if (!normalizePhone(phone)) {
      toast.error(t("auth.invalidPhone"));
      return;
    }
    if (!password) {
      toast.error("Weka password mpya");
      return;
    }
    setLoading(true);
    try {
      const { data, error } = await supabase.functions.invoke("reset-password-by-phone", {
        body: { name: name.trim(), phone, newPassword: password },
      });
      if (error) throw error;
      if ((data as any)?.error) throw new Error((data as any).error);
      toast.success("Password imebadilishwa. Tafadhali ingia.");
      setView("login");
      setPassword("");
    } catch (err: any) {
      toast.error(err?.message || "Imeshindikana kubadilisha password");
    } finally {
      setLoading(false);
    }
  };

  const switchView = (v: View) => {
    setView(v);
    setRegisterStep("type");
    setPassword("");
    setShowPassword(false);
  };

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogContent className="sm:max-w-sm p-0 gap-0 border border-slate-200/50 bg-white/95 text-slate-900 overflow-hidden rounded-3xl shadow-2xl shadow-slate-900/10 backdrop-blur-xl">
        {view !== "forgot" && (
          <div className="relative z-10 px-6 pt-6">
            <div className="flex p-1 rounded-2xl bg-gradient-to-r from-slate-100 to-slate-50 border border-slate-200/50 shadow-lg shadow-slate-200/20 backdrop-blur-sm">
              <button
                type="button"
                onClick={() => switchView("login")}
                className={`flex-1 py-3 text-sm font-semibold rounded-xl transition-all duration-500 ease-out transform ${
                  view === "login"
                    ? "bg-white text-slate-900 shadow-lg shadow-slate-300/30 scale-105 backdrop-blur-sm"
                    : "text-slate-500 hover:text-slate-700 hover:scale-102"
                }`}
              >
                {t("nav.signIn")}
              </button>
              <button
                type="button"
                onClick={() => switchView("register")}
                className={`flex-1 py-3 text-sm font-semibold rounded-xl transition-all duration-500 ease-out transform ${
                  view === "register"
                    ? "bg-white text-slate-900 shadow-lg shadow-slate-300/30 scale-105 backdrop-blur-sm"
                    : "text-slate-500 hover:text-slate-700 hover:scale-102"
                }`}
              >
                {t("nav.signUp")}
              </button>
            </div>
          </div>
        )}

        <div className="relative z-10 px-6 pt-4 pb-2 text-center">
          <img src={zeetopLogo} alt="ZEETOP" className="h-12 w-auto mx-auto mb-2" />
          <h2 className="font-heading text-xl font-semibold tracking-tight text-slate-900">
            {view === "login" && t("auth.welcomeBackTitle")}
            {view === "register" && (registerStep === "type" ? t("auth.chooseAccountTypeTitle") : t("auth.createAccountTitle"))}
            {view === "forgot" && "Sahau Password"}
          </h2>
          {view === "forgot" && (
            <p className="text-xs text-slate-500 mt-1">Weka jina lako na namba ya simu uliyojisajili nayo, kisha chagua password mpya.</p>
          )}
        </div>

        {view === "register" && registerStep === "type" && (
          <div className="relative z-10 px-6 pb-6 pt-4 space-y-4">
            <button
              type="button"
              onClick={() => handleRegisterTypeSelection("buyer")}
              className="group w-full p-6 rounded-2xl border border-slate-200/60 bg-gradient-to-br from-white to-slate-50/50 shadow-lg shadow-slate-200/20 backdrop-blur-sm transition-all duration-500 ease-out transform hover:scale-105 hover:shadow-2xl hover:shadow-violet-200/30 hover:border-violet-300/40 text-center relative overflow-hidden"
            >
              <div className="absolute inset-0 bg-gradient-to-br from-violet-50/20 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-500"></div>
              <div className="relative z-10 text-lg font-semibold text-slate-900 group-hover:text-violet-900 transition-colors duration-300">{t("auth.buyerAccount")}</div>
            </button>
            <button
              type="button"
              onClick={() => handleRegisterTypeSelection("business")}
              className="group w-full p-6 rounded-2xl border border-slate-200/60 bg-gradient-to-br from-white to-slate-50/50 shadow-lg shadow-slate-200/20 backdrop-blur-sm transition-all duration-500 ease-out transform hover:scale-105 hover:shadow-2xl hover:shadow-amber-200/30 hover:border-amber-300/40 text-center relative overflow-hidden"
            >
              <div className="absolute inset-0 bg-gradient-to-br from-amber-50/20 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-500"></div>
              <div className="relative z-10 text-lg font-semibold text-slate-900 group-hover:text-amber-900 transition-colors duration-300">{t("auth.businessAccount")}</div>
            </button>
          </div>
        )}

        {(view === "login" || (view === "register" && registerStep === "details") || view === "forgot") && (
          <form
            onSubmit={
              view === "login" ? handleLogin :
              view === "register" ? handleRegister :
              handleForgotPassword
            }
            className="relative z-10 px-6 pb-6 pt-4 space-y-4"
          >
            {(view === "register" || view === "forgot") && (
              <div className="space-y-1.5">
                <Label htmlFor="auth-name" className="text-slate-600 text-xs font-medium uppercase tracking-wider">{t("auth.fullName")}</Label>
                <Input
                  id="auth-name"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  required
                  placeholder={t("auth.fullNamePlaceholder")}
                  className="h-12 bg-slate-50 border border-slate-200 text-slate-900 placeholder:text-slate-400 rounded-2xl focus:border-violet-500 focus:ring-2 focus:ring-violet-500/20 transition-all"
                />
              </div>
            )}
            <div className="space-y-1.5">
              <Label htmlFor="auth-phone" className="text-slate-600 text-xs font-medium uppercase tracking-wider">{t("auth.phone")}</Label>
              <Input
                id="auth-phone"
                type="tel"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                required
                placeholder="0712 345 678"
                inputMode="tel"
                className="h-12 bg-slate-50 border border-slate-200 text-slate-900 placeholder:text-slate-400 rounded-2xl focus:border-violet-500 focus:ring-2 focus:ring-violet-500/20 transition-all"
              />
            </div>
            <div className="space-y-1.5">
              <div className="flex items-center justify-between">
                <Label htmlFor="auth-password" className="text-slate-600 text-xs font-medium uppercase tracking-wider">
                  {view === "forgot" ? "Password Mpya" : t("auth.password")}
                </Label>
                {view === "login" && (
                  <button
                    type="button"
                    onClick={() => switchView("forgot")}
                    className="text-xs font-semibold text-violet-600 hover:text-violet-700 transition-colors"
                  >
                    Sahau password?
                  </button>
                )}
              </div>
              <div className="relative">
                <Input
                  id="auth-password"
                  type={showPassword ? "text" : "password"}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                  minLength={1}
                  placeholder="••••••••"
                  className="h-12 bg-slate-50 border border-slate-200 text-slate-900 placeholder:text-slate-400 rounded-2xl focus:border-violet-500 focus:ring-2 focus:ring-violet-500/20 transition-all pr-12"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword((s) => !s)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 p-1.5 rounded-lg text-slate-400 hover:text-slate-700 hover:bg-slate-100 transition-colors"
                  aria-label={showPassword ? "Ficha password" : "Onyesha password"}
                  tabIndex={-1}
                >
                  {showPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                </button>
              </div>
            </div>

            <Button
              type="submit"
              disabled={loading}
              className="w-full h-12 bg-gradient-to-r from-violet-500 to-amber-500 text-white font-semibold rounded-2xl hover:from-violet-400 hover:to-amber-400 border-0 shadow-xl shadow-violet-500/30 hover:shadow-2xl hover:shadow-violet-500/40 transition-all duration-300 transform hover:scale-[1.02] active:scale-[0.98]"
            >
              {loading
                ? (view === "login" ? t("auth.signingIn") : view === "register" ? t("auth.creatingAccount") : "Inabadilisha...")
                : (view === "login" ? t("nav.signIn") : view === "register" ? t("auth.createAccount") : "Badilisha Password")}
            </Button>

            {view === "register" && (
              <button
                type="button"
                onClick={() => setRegisterStep("type")}
                className="w-full text-center text-sm text-slate-500 hover:text-slate-700 transition-colors"
              >
                {t("auth.backToTypeSelection")}
              </button>
            )}
            {view === "forgot" && (
              <button
                type="button"
                onClick={() => switchView("login")}
                className="w-full text-center text-sm text-slate-500 hover:text-slate-700 transition-colors flex items-center justify-center gap-1"
              >
                <ArrowLeft className="h-3.5 w-3.5" /> Rudi kwenye Sign In
              </button>
            )}
          </form>
        )}
      </DialogContent>
    </Dialog>
  );
}
