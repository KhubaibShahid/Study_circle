# StudyCircle 🎓

Your self-made university, on your Android phone.

- **Roadmaps** – paste your existing roadmap, build one by hand, or let AI design it. Sections → topics, with a live % completion ring.
- **Notes & YouTube** per topic – write notes, save lectures (thumbnails, opens in the YouTube app).
- **Today** – every day the app tells you the next topic to learn, plus a daily reminder notification at your chosen time.
- **Circles** – invite friends with a 6-letter code: group chat, polls, scheduled classes with **alarms on every member's phone** (15 min before + ringing alarm at start), shared roadmap and a progress leaderboard.
- **Section exams** – when you finish every topic in a section, the exam unlocks: 10 fresh AI-written MCQs, grade A–F, pass at 60%, full review with explanations.
- **AI Tutor** – knows your roadmap and what you've completed; teaches, quizzes, plans your week. English/Urdu/Hinglish.

Stack: Flutter · Firebase Auth + Cloud Firestore (free Spark plan) · flutter_local_notifications · Google Gemini API (free key).

---

## Get the APK without installing Flutter (GitHub builds it)

1. **Firebase** (console.firebase.google.com):
   - Add project → **Build → Authentication** → enable **Email/Password**.
   - **Build → Firestore Database** → Create → paste `firestore.rules` into the **Rules** tab → Publish.
   - Project settings (⚙️) → **Add app → Android** → package name **`com.khubaib.study_circle`** → Register → **download `google-services.json`**.
2. **GitHub**: create a new repository and upload everything in this folder (the website's "Add file → Upload files" works).
3. In the repo → **Settings → Secrets and variables → Actions → New repository secret**:
   name `GOOGLE_SERVICES_JSON`, value = the full contents of `google-services.json`.
4. **Actions tab → Build APK → Run workflow.** Takes ~8 minutes.
5. Open the finished run → **Artifacts → StudyCircle-apk** → download, unzip, send `app-release.apk` to your phone and install it (allow "Install unknown apps").

Every later push to `main` builds a fresh APK automatically.

---

## Setup on your own computer (alternative)

### 0. Tools
- Flutter SDK (stable) + Android Studio (for the Android SDK). Check with `flutter doctor`.
- Node.js (for the Firebase CLI).

### 1. Generate the Android project
Inside this folder:
```bash
flutter create --org com.khubaib --project-name study_circle --platforms android .
flutter pub get
```
(`flutter create` keeps the existing `lib/` code and only adds the `android/` folder.)

### 2. Create the Firebase project
1. Go to https://console.firebase.google.com → **Add project** (Analytics not needed).
2. **Build → Authentication → Get started → Email/Password → Enable.**
3. **Build → Firestore Database → Create database** (production mode, any region — e.g. `asia-south1`).
4. In Firestore → **Rules** tab, paste the contents of `firestore.rules` from this folder → **Publish**.

### 3. Connect the app to Firebase
In Firebase Project settings → **Add app → Android**, package name `com.khubaib.study_circle`, download `google-services.json` and put it in `android/app/`.

### 4. Patch Android for alarms
```bash
dart run tool/patch_android.dart
```

### 5. Run it
Plug in your phone (USB debugging on) and:
```bash
flutter run
```
Or build an installable APK:
```bash
flutter build apk --release
```
→ `build/app/outputs/flutter-apk/app-release.apk`. Send this file to yourself and your friends (WhatsApp/Drive) and install it (allow "Install unknown apps").

### 6. Turn on the AI
Get a free Gemini key at https://aistudio.google.com/apikey → in the app open **Profile → AI tutor & exams** → paste → Save.
Each friend adds their own key (free tier is plenty for personal use).

---

## Using it
1. **Roadmaps → New roadmap → Paste my roadmap.** Format:
   ```
   # React
   - Components & props
   - Hooks
   # Next.js
   - App router
   ```
2. On the roadmap menu choose **Set as daily focus**, then set your reminder time in **Profile**.
3. **Circles → New / Join → Create a circle**, link the roadmap, copy the invite, send it to friends.
4. In the circle chat tap **⏰** to schedule a class or **+** for a poll.
5. Finish all topics of a section → **Take section exam**.

## Make alarms reliable
- On first launch allow **Notifications** and **Alarms & reminders**.
- On Xiaomi / Oppo / Vivo / Realme / Infinix: Settings → Apps → StudyCircle → **Battery: No restrictions** and enable **Autostart**, otherwise the OS can kill scheduled alarms.

## How reminders work (and the current limit)
Alarms are scheduled locally on each phone. A friend's phone picks up a newly scheduled class whenever their app syncs (when they open the app, return to it, or open the circle). If you want classes to reach phones that haven't opened the app at all, the next step is Firebase Cloud Messaging + a Cloud Function (needs Firebase's pay-as-you-go Blaze plan, usually free at this scale).

The daily reminder text ("Today: <topic>") refreshes every time you open the app or tick off a topic.

## Project layout
```
lib/
  main.dart                  app entry + auth gate
  theme.dart                 colors, fonts, theme
  models.dart                Roadmap, Section, Topic, Circle, Message, Session, ExamResult…
  services/
    db.dart                  all Firestore reads/writes
    notifications.dart       daily reminder + class alarms
    reminders.dart           keeps alarms in sync with data
    ai.dart                  Gemini: tutor, exam generator, roadmap generator
    roadmap_parser.dart      pasted text → sections/topics
  screens/                   today, roadmaps, editor, detail, topic, circles, chat, info, exam, tutor, profile
  widgets/common.dart        cards, progress ring, buttons…
firestore.rules              security rules (paste into Firebase console)
tool/patch_android.dart      adds alarm permissions to the Android project
```

## Troubleshooting
- **Version conflict on `flutter pub get`** → run `flutter pub upgrade`. Avoid `--major-versions` for `flutter_local_notifications` (the code targets v19).
- **Gemini "model not found"** → in Profile set the model to a current one listed at https://ai.google.dev/gemini-api/docs/models (e.g. `gemini-2.5-flash`).
- **"permission-denied" errors** → the rules from `firestore.rules` weren't published.
- **App crashes on start** → `android/app/google-services.json` is missing or its package name is not `com.khubaib.study_circle`.
