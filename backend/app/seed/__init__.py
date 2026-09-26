"""Carga de datos de demostración en Firestore: python -m app.seed desde backend/.

Los esquemas están en docs/diccionario_de_datos.md y seed/README.md. Las fechas usan la hora del
servidor de Firestore, no el reloj local (ADR-14). Los UID de las dos cuentas de demostración llegan
por SEED_DEMO_UID y SEED_DEMO_NEW_UID, y sus documentos se llaman usr_ más el UID (ADR-58).
"""
import copy
import hashlib
import json
import re
from collections import Counter
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

from google.cloud.firestore import SERVER_TIMESTAMP

from app.core.config import ADDRESS_BONUS, QUOTA_CAP, SCHOOL_BONUS, get_settings
from app.db.firestore import COL, USER_ID_PATTERN, get_db, user_doc_id
from app.services.questions import elapsed_bucket

DATA = Path(__file__).parent / "data"
TIERS = ("bronze", "silver", "gold", "diamond", "platinum")
# Cuenta de demostración -> variable de entorno con su UID
ROLES = {"demo": "SEED_DEMO_UID", "nuevo": "SEED_DEMO_NEW_UID"}
# Percentil que recibe una respuesta sin cohorte previa en el histograma (ADR-63)
SIN_COHORTE = 50


def load(name: str):
    return json.loads((DATA / f"{name}.json").read_text(encoding="utf-8"))


def demo_uids(settings) -> dict[str, str]:
    """UID de cada cuenta de demostración, validados antes de abrir Firestore."""
    uids = {}
    for role, variable in ROLES.items():
        uid = getattr(settings, variable.lower())
        if not uid:
            raise RuntimeError(f"Falta {variable}: el seed necesita el UID de cada cuenta de demostración.")
        if not USER_ID_PATTERN.fullmatch(user_doc_id(uid)):
            raise RuntimeError(f"{variable} no da un ID de users que acepte la administración (ADR-58).")
        uids[role] = uid
    return uids


def _id(prefijo: str, semilla: str) -> str:
    # IDs fijos con el formato de la administración, para que volver a correr el seed reescriba los mismos documentos.
    return f"{prefijo}_{hashlib.sha1(semilla.encode('utf-8')).hexdigest()[:10]}"


def _preview(statement: str) -> str:
    # statementPreview de la cola de recorrecciones: un renglón de hasta 120 caracteres.
    texto = " ".join(statement.split())
    return texto if len(texto) <= 120 else texto[:119] + "…"


def build_documents(uids: dict[str, str], today: str) -> list[tuple[str, dict]]:
    """Arma todos los documentos del seed como (ruta, datos), sin tocar Firestore."""
    tests, skills, plans, features = load("tests"), load("skills"), load("plans"), load("features")
    questions = {q["id"]: copy.deepcopy(q) for q in load("questions")}
    users, answers, corrections = load("users"), load("answers"), load("corrections")
    plan_by_id = {p["id"]: p for p in plans}
    skill_by_id = {s["id"]: s for s in skills}
    docs: list[tuple[str, dict]] = []

    for p in plans:
        # nameLower: la administración lo usa para rechazar dos planes con el mismo nombre.
        docs.append((f"{COL.plans}/{p['id']}", {**p, "nameLower": p["name"]["es"].lower(),
                                                  "createdAt": SERVER_TIMESTAMP, "updatedAt": SERVER_TIMESTAMP}))
    for f in features:
        docs.append((f"{COL.features}/{f['id']}", f))
    for s in skills:
        docs.append((f"{COL.skills}/{s['id']}", {**s, "createdAt": SERVER_TIMESTAMP, "updatedAt": SERVER_TIMESTAMP}))

    names = {}
    for u in users:
        role = u["role"]
        doc_id = user_doc_id(uids[role])
        names[role] = u["name"]
        plan = plan_by_id[u["plan"]]
        wallet = dict.fromkeys(TIERS, 0)
        mastery: dict[str, Counter] = {}
        answered = []

        for a in answers.get(role, []):
            q = questions[a["questionId"]]
            correct = a["selected"] == q["correctAnswer"]
            answered.append(q["id"])
            docs.append((f"{COL.users}/{doc_id}/{COL.answers}/ans_{q['id'][4:]}", {
                "questionId": q["id"], "testId": q["testId"], "axis": q["axis"], "skillId": q["skillId"],
                "selected": a["selected"], "correct": correct, "elapsedMs": a["elapsedMs"],
                "cohortPercentile": SIN_COHORTE, "difficulty": q["difficulty"], "answeredAt": SERVER_TIMESTAMP,
            }))
            stats = q["stats"]
            stats["timesAnswered"] += 1
            stats["timesCorrect"] += int(correct)
            stats["sumElapsedMs"] += a["elapsedMs"]
            stats["elapsedBuckets"][elapsed_bucket(a["elapsedMs"])] += 1
            mastery.setdefault(q["skillId"], Counter()).update(total=1, correct=int(correct))
            if correct:
                amount = plan["badges"]["correct"]
                wallet["bronze"] += amount
                mtx_id = _id("mtx", f"answer_correct|{role}|{q['id']}")
                docs.append((f"{COL.medal_transactions}/{mtx_id}", {
                    "userId": doc_id, "tier": "bronze", "amount": amount, "reason": "answer_correct",
                    "refId": q["id"], "at": SERVER_TIMESTAMP,
                }))

        for skill_id, c in mastery.items():
            skill = skill_by_id[skill_id]
            level = min(skill["maxLevel"], c["correct"])
            docs.append((f"{COL.users}/{doc_id}/{COL.skill_mastery}/{skill_id}", {
                "testId": skill["testId"], "correct": c["correct"], "total": c["total"],
                "percent": round(100 * c["correct"] / c["total"]), "level": level,
                "status": "mastered" if level == skill["maxLevel"] else "in_progress", "updatedAt": SERVER_TIMESTAMP,
            }))

        practice = {"answeredQuestionIds": answered}
        if answered:
            practice.update(lastQuestionId=answered[-1], lastAnsweredAt=SERVER_TIMESTAMP)
        docs.append((f"{COL.users}/{doc_id}/{COL.state}/practice", practice))

        q_day = plan["limits"]["qDay"]
        bonus = SCHOOL_BONUS * u["quota"]["bonusSchool"] + ADDRESS_BONUS * u["quota"]["bonusAddress"]
        profile = {k: v for k, v in u.items() if k not in ("role", "quota")}
        docs.append((f"{COL.users}/{doc_id}", {
            **profile,
            "nameLower": u["name"].lower(), "emailLower": u["email"].lower(),
            "medalWallet": wallet, "badgesTotal": sum(wallet.values()),
            "quota": {"used": len(answered), "max": 0 if q_day == 0 else min(q_day + bonus, QUOTA_CAP), "date": today,
                      **u["quota"], "unlimited": q_day == 0},
            # lastActivityAt, badgesTotal y nameLower existen siempre: la consola ordena por ellos y
            # Firestore deja fuera de una consulta ordenada los documentos que no tienen el campo.
            "createdAt": SERVER_TIMESTAMP, "updatedAt": SERVER_TIMESTAMP, "lastActivityAt": SERVER_TIMESTAMP,
        }))

    for c in corrections:
        q = questions[c["questionId"]]
        q["flagCount"] += 1
        docs.append((f"{COL.corrections}/{c['id']}", {
            "userId": user_doc_id(uids[c["role"]]), "userName": names[c["role"]], "questionId": q["id"],
            "testId": q["testId"], "axis": q["axis"], "difficulty": q["difficulty"],
            "statementPreview": _preview(q["statement"]), "reason": c["reason"], "proposedAnswer": c["proposedAnswer"],
            # reasonCode y comment: lo que envía la app, según la propuesta de ADR-67.
            "reasonCode": c["reasonCode"], "comment": c["comment"],
            "state": "pending", "createdAt": SERVER_TIMESTAMP, "resolvedAt": None, "resolvedBy": None,
            "note": None, "rewardGranted": None,
        }))

    approved = Counter(q["testId"] for q in questions.values() if q["reviewStatus"] == "approved")
    for t in tests:
        docs.append((f"{COL.tests}/{t['id']}", {**t, "approvedStock": approved[t["id"]]}))
    for q in questions.values():
        docs.append((f"{COL.questions}/{q['id']}", {**q, "createdAt": SERVER_TIMESTAMP, "updatedAt": SERVER_TIMESTAMP}))
    return [(ruta, {k: v for k, v in datos.items() if k != "id"}) for ruta, datos in docs]


async def seed_database() -> None:
    settings = get_settings()
    if not settings.firestore_emulator_host and not settings.seed_allow_remote:
        raise RuntimeError("Seed remoto bloqueado. Define SEED_ALLOW_REMOTE=true para permitirlo.")
    uids = demo_uids(settings)
    today = datetime.now(ZoneInfo(settings.quota_reset_timezone)).date().isoformat()
    docs = build_documents(uids, today)
    print("[Seed] Iniciando siembra de datos en Firestore...")
    db = get_db()
    batch = db.batch()  # un solo lote: o se escribe todo o nada
    for ruta, datos in docs:
        batch.set(db.document(ruta), datos)
    await batch.commit()
    por_coleccion = Counter(re.sub(r"^users/[^/]+/", "users/{uid}/", ruta.rsplit("/", 1)[0]) for ruta, _ in docs)
    for coleccion, n in sorted(por_coleccion.items()):
        print(f"[Seed] {n} documentos en {coleccion}")
    print(f"[Seed] ¡Siembra de datos finalizada con éxito! {len(docs)} documentos.")
