# 🚛 TransportHub — Documentation Complète

## Architecture du projet

```
transport_hub/
├── lib/
│   ├── core/
│   │   ├── constants/app_constants.dart      # Config globale, tables, buckets
│   │   └── theme/app_theme.dart              # Material 3, light/dark, couleurs
│   ├── data/
│   │   ├── models/models.dart                # Tous les modèles (ProfileModel, TransporterModel…)
│   │   └── services/
│   │       ├── supabase_service.dart         # Singleton Supabase (DB + Storage + Realtime)
│   │       ├── firebase_service.dart         # Firebase Auth + FCM + Local Notifs
│   │       └── tracking_service.dart         # Background tracking Uber/Yassir style
│   ├── presentation/
│   │   ├── providers/
│   │   │   ├── auth_provider.dart            # Auth state, login, signup, rôles
│   │   │   ├── transport_provider.dart       # Demandes, tracking realtime, notifs
│   │   │   └── providers.dart               # TransporterProvider, AdminProvider, NotifProvider…
│   │   ├── screens/
│   │   │   ├── auth/auth_screens.dart        # Login, Register (rôle), ForgotPassword
│   │   │   ├── public/public_home_screen.dart# Carte OSM + liste transporteurs + filtres
│   │   │   ├── transporter/                  # Home transporteur, setup, premium store
│   │   │   ├── supervisor/                   # Home superviseur, QR code, objectifs
│   │   │   ├── admin/                        # Dashboard, validation, règles métier
│   │   │   └── shared/                       # Profil, notifications
│   │   └── widgets/widgets.dart             # AppButton, AppTextField, TrackingMap, TransporterCard…
│   └── main.dart                             # App root, MultiProvider, GoRouter, ThemeProvider
├── supabase_schema.sql                       # Schéma SQL complet avec RLS + triggers + fonctions
└── pubspec.yaml                              # Dépendances production
```

---

## 🚀 Installation pas à pas

### 1. Prérequis
```bash
flutter --version  # >= 3.24.0
dart --version     # >= 3.4.0
```

### 2. Cloner et installer les dépendances
```bash
git clone <repo>
cd transport_hub
flutter pub get
```

### 3. Firebase Setup
```bash
# Installer FlutterFire CLI
dart pub global activate flutterfire_cli

# Configurer (Android + Windows)
flutterfire configure --platforms=android,windows
```

Activer dans la console Firebase :
- **Authentication** → Email/Password + Google Sign-In
- **Cloud Messaging** (FCM)

### 4. Supabase Setup
1. Créer un projet sur [supabase.com](https://supabase.com)
2. Aller dans **SQL Editor** → coller le contenu de `supabase_schema.sql` → Run
3. Dans **Storage** → créer les buckets : `avatars`, `vehicles`, `documents`, `listings` (tous en **Public**)
4. Dans **Database → Replication** → activer Realtime sur : `trackings`, `transport_requests`, `notifications_log`
5. Copier l'URL et la clé anon dans `lib/core/constants/app_constants.dart`

### 5. Supabase Third-Party Auth (Firebase)
Dans le dashboard Supabase → **Authentication → Providers → Custom JWT** :
```json
{
  "jwks_uri": "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com",
  "issuer": "https://securetoken.google.com/YOUR_FIREBASE_PROJECT_ID"
}
```

### 6. Android — Permissions AndroidManifest.xml
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

<!-- Dans <application> -->
<service
  android:name="id.flutter.flutter_background_service.BackgroundService"
  android:foregroundServiceType="location"
  android:exported="false"/>
```

### 7. Supabase Edge Function — Notifications FCM
```bash
supabase functions new send-notification
```
```typescript
// supabase/functions/send-notification/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

serve(async (req) => {
  const { recipient_profile_id, title, body, data } = await req.json()
  const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)

  // Récupérer le token FCM
  const { data: tokenData } = await supabase
    .from('fcm_tokens')
    .select('token')
    .eq('profile_id', recipient_profile_id)
    .eq('is_active', true)
    .single()

  if (!tokenData?.token) {
    // Fallback: notif en base seulement
    await supabase.from('notifications_log').insert({ recipient_id: recipient_profile_id, title, body, data })
    return new Response(JSON.stringify({ ok: true, fcm: false }))
  }

  // Envoyer FCM via Google APIs
  const fcmResponse = await fetch('https://fcm.googleapis.com/v1/projects/YOUR_PROJECT/messages:send', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${Deno.env.get('FIREBASE_SERVICE_ACCOUNT_TOKEN')}`,
    },
    body: JSON.stringify({
      message: { token: tokenData.token, notification: { title, body }, data }
    })
  })

  // Sauvegarder dans la base
  await supabase.from('notifications_log').insert({
    recipient_id: recipient_profile_id, title, body, data, sent_via_fcm: fcmResponse.ok
  })

  return new Response(JSON.stringify({ ok: fcmResponse.ok }))
})
```

### 8. Lancer l'app
```bash
# Android
flutter run --target lib/main.dart

# Windows Desktop
flutter run -d windows --target lib/main.dart
```

---

## 🔧 Fichiers écrans à créer (stubs)

Ces fichiers sont référencés dans `main.dart` et doivent être créés :

```
lib/presentation/screens/
├── public/
│   ├── transporter_detail_screen.dart  # Détail transporteur + demande
│   ├── request_screen.dart             # Formulaire de demande de transport
│   ├── history_screen.dart             # Historique des courses
│   └── tracking_screen.dart           # ← Déjà dans admin_screens.dart
├── transporter/
│   ├── transporter_setup_screen.dart   # Formulaire profil + upload docs
│   ├── transporter_request_screen.dart # Gestion course en cours
│   └── premium_store_screen.dart       # Achat options premium
├── supervisor/
│   └── supervisor_add_transporter_screen.dart
├── admin/
│   ├── admin_transporter_validation_screen.dart  ← admin_screens.dart
│   ├── admin_business_rules_screen.dart          ← admin_screens.dart
│   └── admin_supervisors_screen.dart
├── marketplace/
│   ├── marketplace_screen.dart
│   ├── listing_detail_screen.dart
│   └── create_listing_screen.dart
└── shared/
    ├── profile_screen.dart
    ├── notifications_screen.dart
    └── onboarding_screen.dart
```

---

## 💡 Suggestions Expert — Fonctionnalités V2

### 🔒 Sécurité
- [ ] Vérification OTP téléphone (Supabase Phone Auth)
- [ ] Anti-fraud: blocage IP après N tentatives
- [ ] Watermark sur les documents uploadés

### 💰 Revenus
- [ ] Intégration CinetPay / PayDunya pour paiements en ligne
- [ ] Facture PDF auto générée (dart:pdf)
- [ ] Portefeuille virtuel superviseur avec historique retraits

### 🗺️ Expérience
- [ ] Calcul itinéraire OSRM (routing open source) entre pickup/dropoff
- [ ] ETA dynamique mis à jour en temps réel
- [ ] Stories transporteur (disponible dans X heures)
- [ ] Surge pricing automatique (déclenchement par trigger Supabase si >15 demandes/heure)

### 📊 Analytics
- [ ] Dashboard analytics Supabase avec fl_chart
- [ ] Export Excel commissions superviseurs
- [ ] Heatmap zones de demande par heure

### 🤖 IA
- [ ] Suggestion de prix automatique basée sur historique
- [ ] Détection de fraude sur les documents (OCR via Edge Function)
- [ ] Chatbot assistant client (Gemini API)

---

## 🎨 Design Tokens

| Token | Valeur |
|-------|--------|
| Primary | #FF6B35 |
| Secondary | #1A1A2E |
| Success | #4CAF50 |
| Warning | #FFC107 |
| Error | #E53935 |
| Premium Gold | #FFD700 |
| Border Radius | 14px (champs), 16px (cards), 20px (containers) |
| Font | Poppins (400/500/600/700) |

---

## 📐 Architecture Décisions

| Choix | Raison |
|-------|--------|
| Provider (pas Riverpod/Bloc) | Demande explicite client, simplicité pour équipe mixte |
| Firebase Auth + Supabase DB | Firebase = Auth/FCM mature, Supabase = Realtime/RLS puissant |
| Supabase Realtime (WebSocket) | Tracking live sans polling, 0 coût supplémentaire |
| Background Service | flutter_background_service = seule solution cross-platform Android/Windows |
| GoRouter | Navigation déclarative, redirect par rôle, deep linking |
| OSM + flutter_map | 100% gratuit, pas de limite d'appels, customisable |
| RLS Supabase | Sécurité au niveau base de données, pas côté client uniquement |
#   T R A N S P O R T  
 