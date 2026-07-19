/**
 * Pure Pets — Title Update Script
 *
 * Truncates pet ad titles (adTitle) and accessory names (name) to at most 3
 * meaningful words. Falls back to the description field when truncation would
 * damage meaning.
 *
 * Usage:
 *   1. Set GOOGLE_APPLICATION_CREDENTIALS or pass a path below
 *   2. npm install (installs firebase-admin)
 *   3. node scripts/update_titles.js [--dry-run]
 *
 * Flags
 *   --dry-run    Log every change without writing to Firestore.
 *   --collection pet_ads|petAccessories|both   (default: both)
 */

const admin = require("firebase-admin");
const readline = require("readline");

// ─── Configuration ────────────────────────────────────────────────────────────

// Set process.env.GOOGLE_APPLICATION_CREDENTIALS to your service-account JSON
// path before running, OR paste the path here:
const SERVICE_ACCOUNT_PATH = process.env.GOOGLE_APPLICATION_CREDENTIALS || "";

const DRY_RUN   = process.argv.includes("--dry-run");
const TARGET    = process.argv
  .find((a) => a.startsWith("--collection="))
  ?.split("=")[1] ?? "both";

// ─── Stop words ───────────────────────────────────────────────────────────────

const ENGLISH_STOP = new Set([
  "the","a","an","for","with","and","or","&","in","on","at","to","of","is",
  "are","was","were","been","being","have","has","had","do","does","did",
  "will","would","could","should","may","might","shall","can","need","dare",
  "ought","used","this","that","these","those","it","its","my","your","his",
  "her","their","our","some","any","no","every","each","all","both","few",
  "many","much","several","most","enough","such","so","too","very","quite",
  "rather","pretty","really","just","only","also","then","well","now","here",
  "there","about","above","across","after","against","along","among","around",
  "at","before","behind","below","beneath","beside","between","beyond","by",
  "down","during","except","from","inside","into","near","off","outside",
  "over","since","through","throughout","under","underneath","until","up",
  "upon","with","within","without","via","not","but","because","as","if",
  "than","that","first","second","last","next","more","less","like","please",
  "kindly","dear","hello","hi"
]);

const ARABIC_STOP = new Set([
  "في","من","على","إلى","عن","مع","بين","خلال","حسب","دون","حول","ضد",
  "عبر","بعد","قبل","عند","تحت","فوق","لدى","نحو","حتى","منذ","غير",
  "سوى","كل","بعض","أي","ذلك","هذا","هذه","تلك","هؤلاء","الذي","التي",
  "الذين","ما","من","هل","لم","لن","إن","أن","كان","كانت","يكون","تكون",
  "لكن","لعل","ليت","ثم","أو","و","ف","ب","ل","ك","ال","أ","إ","إذا",
  "إذ","حيث","بينما","حين","عندما","لأن","كي","لا","بلى","أجل","كلا",
  "هناك","هنا","نعم","أيضا","قد","ربما","لو","لولا","لوما","سوف","سن",
  "سـ","لقد","ولقد","قد","قط","لن","لم","لما","لـ","بال","بـ","فلن",
  "فلم","فلا","ولن","ولم","ولن"
]);

function isStopWord(w) {
  if (!w) return true;
  return ENGLISH_STOP.has(w.toLowerCase()) || ARABIC_STOP.has(w);
}

// ─── Core title logic ─────────────────────────────────────────────────────────

function meaningfulWords(text) {
  if (!text) return [];
  const tokens = text.trim().split(/\s+/);
  return tokens.filter((t) => !isStopWord(t) && t.length > 0);
}

function truncateTitle(originalTitle, description) {
  if (!originalTitle) return { title: "", derived: false };

  const raw = originalTitle.trim();
  const words = raw.split(/\s+/);

  // Already ≤ 3 words — keep as-is
  if (words.length <= 3) return { title: raw, derived: false };

  const mWords = meaningfulWords(raw);

  // No meaningful words at all — try description
  if (mWords.length === 0) {
    return deriveFromDescription(raw, description);
  }

  // Already 1–3 meaningful words — join & use
  if (mWords.length <= 3) {
    return { title: mWords.join(" "), derived: false };
  }

  // ── More than 3 meaningful words → truncate ──
  let candidate = mWords.slice(0, 3).join(" ");

  // Check for a key classifier word in the original that might be lost.
  // Common classifier patterns: عربي شيرازي هولندي كناري ببغاء قط كلب + English equivalents
  const classifiers = new Set([
    // Animal types
    "cat","cats","kitten","kittens","dog","dogs","puppy","puppies","bird","birds",
    "parrot","parakeet","canary","finch","cockatiel","lovebird","macaw","conure",
    "horse","horses","pony","ponies","camel","camels","sheep","fish","deer","falcon",
    "rabbit","rabbits","hamster","hamsters","turtle","turtles","chicken","chickens",
    "duck","ducks","pigeon","pigeons","peacock","peacocks",
    // Arabic animal types
    "قط","قطط","هر","هرة","كلب","كلاب","جرو","طير","طيور","ببغاء","ببغاوات",
    "كناري","كنار","عصفور","عصافير","حسون","كروان","درة","روز","كوكاتيل",
    "حبش","فنش","مكاو","كونيور","لوف بيرد","بادجي","استرالي",
    "حصان","خيل","فرس","جمل","جمال","ناقة","خروف","غنم","سمك","سمكة","غزال",
    "غزلان","صقر","صقور","شاهين","عربي","شيرازي","هولندي","بريطاني",
    // Product / service classifiers
    "food","feed","طعام","اكل","أكل","علف","حبوب","medicine","دواء","علاج",
    "vaccine","vaccination","تطعيم","لقاح","accessory","accessories","ملحق",
    "مستلزمات","لوازم"," cage","قفص","اقفاص","carrier","ناقل","بيت","منزل",
    "house","bed","سرير","فراش","toy","لعبة","لعبه","collars","طوق","leash",
    "مقود","bowl","طبق","وعاء","litter","فضلات","grooming","حلاقة","تجميل",
    "shampoo","شامبو","soap","صابون","towel","منشفة",
    // Breed / color qualifiers that matter
    "white","black","brown","gray","grey","golden","red","blue","green","yellow",
    "orange","pink","purple","بيضاء","ابيض","اسود","سوداء","بني","رمادي",
    "ذهبي","احمر","ازرق","اخضر","اصفر","برتقالي","وردي","بنفسجي",
    "persian","شيرازي","siamese","سيامي","maine","coon","sphynx","spyhnx",
    "british","بريطاني","short","shorthair","longhair","fold","scottish",
    "bengal","بنقال","ragdoll","abyssinian","حبيشي",
    "german","shepherd","labrador","retriever","poodle","bulldog","beagle",
    "boxer","dachshund","husky","chihuahua","pomeranian","yorkie","maltese",
    "shih","tzu","pug","cocker","spaniel","doberman","rottweiler","great","dane",
    "pure","bred","mix","cross","هجين"
  ]);

  // Check if an important classifier is in the original but not in the candidate
  const originalLower = words.map((w) => w.toLowerCase());
  const candidateLower = candidate.toLowerCase();

  const missingClassifiers = words.filter((w) => {
    const wl = w.toLowerCase();
    return classifiers.has(wl) && !candidateLower.includes(wl);
  });

  if (missingClassifiers.length > 0) {
    // Try to include the most important missing classifier
    // Strategy: take first 2 meaningful words + the missing classifier
    const firstTwo = mWords.slice(0, 2);
    for (const mc of missingClassifiers) {
      const mcClean = mc.replace(/[^a-zA-Z\u0600-\u06FF]/g, "");
      if (mcClean.length < 2) continue;
      // Check this word is not already in firstTwo
      if (!firstTwo.some((w) => w.toLowerCase() === mcClean.toLowerCase())) {
        candidate = firstTwo.join(" ") + " " + mcClean;
        break;
      }
    }
  }

  // Verify candidate has ≥ 2 meaningful words
  const cWords = meaningfulWords(candidate);
  if (cWords.length < 2) {
    return deriveFromDescription(raw, description);
  }

  // Clean up extra whitespace
  candidate = candidate.replace(/\s+/g, " ").trim();
  return { title: candidate, derived: false };
}

function deriveFromDescription(originalTitle, description) {
  if (!description) return { title: originalTitle, derived: false };

  // Take the first sentence of the description
  const sentences = description
    .replace(/([.!?\n])+/g, "$1\n")
    .split("\n")
    .map((s) => s.trim())
    .filter(Boolean);

  const firstSentence = sentences[0] || description;

  // Check if description contains any of the original title's meaningful words
  const origMeaningful = meaningfulWords(originalTitle);
  const descWords = firstSentence.split(/\s+/);
  const relevantDescWords = descWords.filter((dw) => {
    const clean = dw.replace(/[^a-zA-Z\u0600-\u06FF]/g, "");
    return (
      origMeaningful.some(
        (ow) => ow.toLowerCase() === clean.toLowerCase()
      ) || !isStopWord(clean)
    );
  });

  const titleFromDesc = meaningfulWords(firstSentence);
  if (titleFromDesc.length >= 2) {
    const truncated = titleFromDesc.slice(0, 3).join(" ");
    return { title: truncated, derived: true, from: "description" };
  }

  // Fallback: keep original if we can't derive anything better
  return { title: originalTitle, derived: false };
}

// ─── Firestore helpers ────────────────────────────────────────────────────────

async function processAds(db, log) {
  log("=== Processing pet_ads (field: adTitle) ===");
  const snap = await db.collection("pet_ads").get();
  log(`Found ${snap.size} documents`);

  let updated = 0;
  let skipped = 0;
  const batchSize = 400;

  for (let i = 0; i < snap.size; i += batchSize) {
    const batch = db.batch();
    const docs = snap.docs.slice(i, i + batchSize);
    let batchWrites = 0;

    for (const doc of docs) {
      const data = doc.data();
      const oldTitle = data.adTitle || "";
      const desc = data.desc || "";

      if (!oldTitle) {
        skipped++;
        continue;
      }

      const { title: newTitle, derived } = truncateTitle(oldTitle, desc);

      if (newTitle === oldTitle) {
        skipped++;
        continue;
      }

      const change = {
        id: doc.id,
        old: oldTitle.length > 60 ? oldTitle.substring(0, 60) + "…" : oldTitle,
        new: newTitle,
        derived,
      };
      log(`  [${derived ? "DERIVED" : "TRUNC"}] #${i + docs.indexOf(doc) + 1} ${doc.id}`);
      log(`    OLD: ${change.old}`);
      log(`    NEW: ${change.new}`);

      if (!DRY_RUN) {
        batch.update(doc.ref, { adTitle: newTitle });
        batchWrites++;
      }
      updated++;
    }

    if (!DRY_RUN && batchWrites > 0) {
      await batch.commit();
      log(`  Committed batch of ${batchWrites} writes`);
    }
  }

  log(`\npet_ads: ${updated} updated, ${skipped} skipped\n`);
  return updated;
}

async function processAccessories(db, log) {
  log("=== Processing petAccessories (field: name) ===");
  const snap = await db.collection("petAccessories").get();
  log(`Found ${snap.size} documents`);

  let updated = 0;
  let skipped = 0;
  const batchSize = 400;

  for (let i = 0; i < snap.size; i += batchSize) {
    const batch = db.batch();
    const docs = snap.docs.slice(i, i + batchSize);
    let batchWrites = 0;

    for (const doc of docs) {
      const data = doc.data();
      const oldName = data.name || "";
      const desc = data.desc || "";

      if (!oldName) {
        skipped++;
        continue;
      }

      const { title: newName, derived } = truncateTitle(oldName, desc);

      if (newName === oldName) {
        skipped++;
        continue;
      }

      const change = {
        id: doc.id,
        old: oldName.length > 60 ? oldName.substring(0, 60) + "…" : oldName,
        new: newName,
        derived,
      };
      log(`  [${derived ? "DERIVED" : "TRUNC"}] #${i + docs.indexOf(doc) + 1} ${doc.id}`);
      log(`    OLD: ${change.old}`);
      log(`    NEW: ${change.new}`);

      if (!DRY_RUN) {
        batch.update(doc.ref, { name: newName });
        batchWrites++;
      }
      updated++;
    }

    if (!DRY_RUN && batchWrites > 0) {
      await batch.commit();
      log(`  Committed batch of ${batchWrites} writes`);
    }
  }

  log(`\npetAccessories: ${updated} updated, ${skipped} skipped\n`);
  return updated;
}

// ─── Confirm & run ────────────────────────────────────────────────────────────

async function confirmAction() {
  if (DRY_RUN) return true;
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });
  return new Promise((resolve) => {
    rl.question(
      "\n⚠️  This will WRITE to Firestore. Continue? (yes/no) ",
      (ans) => {
        rl.close();
        resolve(ans.toLowerCase() === "yes");
      }
    );
  });
}

async function main() {
  if (!SERVICE_ACCOUNT_PATH) {
    console.error(
      "❌ Set GOOGLE_APPLICATION_CREDENTIALS env var to your service-account JSON."
    );
    process.exit(1);
  }

  const mode = DRY_RUN ? "🔍 DRY RUN (no writes)" : "✏️  LIVE UPDATE";
  console.log(`\n${"═".repeat(60)}`);
  console.log(`   Pure Pets — Title Update Script`);
  console.log(`   Mode: ${mode}`);
  console.log(`   Target: ${TARGET}`);
  console.log(`${"═".repeat(60)}\n`);

  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });
  const db = admin.firestore();

  const log = (msg) => console.log(msg);
  const nl = () => log("");

  let total = 0;

  if (TARGET === "both" || TARGET === "pet_ads") {
    await processAds(db, log);
  }
  if (TARGET === "both" || TARGET === "petAccessories") {
    await processAccessories(db, log);
  }

  nl();
  log(`${"═".repeat(60)}`);
  log(`   Done.${DRY_RUN ? " (dry run — no data written)" : ""}`);
  log(`${"═".repeat(60)}`);
  await admin.app().delete();
}

// Run only from CLI
if (require.main === module) {
  confirmAction().then((ok) => {
    if (!ok) {
      console.log("Aborted.");
      process.exit(0);
    }
    main().catch((err) => {
      console.error("Fatal:", err);
      process.exit(1);
    });
  });
}
