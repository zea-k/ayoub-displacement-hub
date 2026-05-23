import { useState } from "react";
import { useTranslation } from "react-i18next";
import { Dialog, DialogContent } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useAuth } from "@/contexts/AuthContext";
import { toast } from "sonner";
import { useNavigate } from "react-router-dom";
import zeetopLogo from "@/assets/zeetop-logo.png";
import { normalizePhone } from "@/lib/phone-auth";
import type { UserType } from "@/types/subscription";

interface AuthModalProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  defaultView?: "login" | "register";
}

export default function AuthModal({ open, onOpenChange, defaultView = "login" }: AuthModalProps) {
  const { t } = useTranslation();
  const [view, setView] = useState<"login" | "register">(defaultView);
  const [registerStep, setRegisterStep] = useState<"type" | "details">("type");
  const [name, setName] = useState("");
  const [phone, setPhone] = useState("");
  const [password, setPassword] = useState("");
  const [userType, setUserType] = useState<UserType>("buyer");
  const [loading, setLoading] = useState(false);
  const { signIn, signUp } = useAuth();
  const navigate = useNavigate();

  const handleOpenChange = (val: boolean) => {
    if (val) {
      setView(defaultView);
      setRegisterStep("type");
    }
    onOpenChange(val);
    if (!val) {
      setName("");
      setPhone("");
      setPassword("");
      setUserType("buyer");
      setRegisterStep("type");
    }
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
    if (!password) {
      return;
    }
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

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogContent className="sm:max-w-sm p-0 gap-0 border border-slate-200/50 bg-white/95 text-slate-900 overflow-hidden rounded-3xl shadow-2xl shadow-slate-900/10 backdrop-blur-xl">
        <div className="relative z-10 px-6 pt-6">
          <div className="flex p-1 rounded-2xl bg-gradient-to-r from-slate-100 to-slate-50 border border-slate-200/50 shadow-lg shadow-slate-200/20 backdrop-blur-sm">
            <button
              type="button"
              onClick={() => { setView("login"); setRegisterStep("type"); }}
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
              onClick={() => { setView("register"); setRegisterStep("type"); }}
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

        <div className="relative z-10 px-6 pt-4 pb-2 text-center">
          <img src={zeetopLogo} alt="ZEETOP" className="h-12 w-auto mx-auto mb-2" />
          <h2 className="font-heading text-xl font-semibold tracking-tight text-slate-900">
            {view === "login" ? (
              <>{t("auth.welcomeBackTitle")}</>
            ) : registerStep === "type" ? (
              <>{t("auth.chooseAccountTypeTitle")}</>
            ) : (
              <>{t("auth.createAccountTitle")}</>
            )}
          </h2>
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

        {(view === "login" || (view === "register" && registerStep === "details")) && (
          <form
            onSubmit={view === "login" ? handleLogin : handleRegister}
            className="relative z-10 px-6 pb-6 pt-4 space-y-4"
          >
            {view === "register" && (
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
              <Label htmlFor="auth-password" className="text-slate-600 text-xs font-medium uppercase tracking-wider">{t("auth.password")}</Label>
              <Input
                id="auth-password"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                minLength={1}
                placeholder="••••••••"
                className="h-12 bg-slate-50 border border-slate-200 text-slate-900 placeholder:text-slate-400 rounded-2xl focus:border-violet-500 focus:ring-2 focus:ring-violet-500/20 transition-all"
              />
            </div>

            <Button
              type="submit"
              disabled={loading}
              className="w-full h-12 bg-gradient-to-r from-violet-500 to-amber-500 text-white font-semibold rounded-2xl hover:from-violet-400 hover:to-amber-400 border-0 shadow-xl shadow-violet-500/30 hover:shadow-2xl hover:shadow-violet-500/40 transition-all duration-300 transform hover:scale-[1.02] active:scale-[0.98]"
            >
              {loading
                ? (view === "login" ? t("auth.signingIn") : t("auth.creatingAccount"))
                : (view === "login" ? t("nav.signIn") : t("auth.createAccount"))}
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
          </form>
        )}
      </DialogContent>
    </Dialog>
  );
}
