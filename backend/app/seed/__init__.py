"""Carga de datos de demostración en Firestore: python -m app.seed desde backend/.

Los JSON de data/ salieron de backend/src/seed/data.js; los esquemas están en seed/README.md.
Las fechas usan la hora del servidor de Firestore, no el reloj local (ADR-14).
"""
import json
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

from google.cloud.firestore import SERVER_TIMESTAMP

from app.core.config import get_settings
from app.db.firestore import COL, get_db

DATA = Path(__file__).parent / "data"


def load(name: str):
    return json.loads((DATA / f"{name}.json").read_text(encoding="utf-8"))


async def seed_database() -> None:
    settings = get_settings()
    if not settings.firestore_emulator_host and not settings.seed_allow_remote:
        raise RuntimeError("Seed remoto bloqueado. Define SEED_ALLOW_REMOTE=true para permitirlo.")
    print("[Seed] Iniciando siembra de datos en Firestore...")
    db = get_db()
    tests, skills, questions = load("tests"), load("skills"), load("questions")
    users, practice_states = load("users"), load("practice_states")

    # 1. Colección tests (5 pruebas PAES)
    for t in tests:
        await db.collection(COL.tests).document(t["id"]).set(t)
    print(f"[Seed] {len(tests)} pruebas PAES insertadas en /tests")

    # 2. Colección skills
    for s in skills:
        await db.collection(COL.skills).document(s["id"]).set(s)
    print(f"[Seed] {len(skills)} habilidades insertadas en /skills")

    # 3. Colección questions (con correctAnswer y cohortSpeedThresholds)
    for q in questions:
        await db.collection(COL.questions).document(q["id"]).set(q)
    print(f"[Seed] {len(questions)} preguntas insertadas en /questions")

    # 4. Documentos users/{uid} de los usuarios de demostración (ADR-27)
    hoy = datetime.now(ZoneInfo(settings.quota_reset_timezone)).date().isoformat()
    for u in users:
        uid, usuario = u["id"], {k: v for k, v in u.items() if k != "id"}
        await db.collection(COL.users).document(uid).set({
            **usuario,
            "quota": {**usuario["quota"], "date": hoy},
            "lastActiveDate": hoy,
            "createdAt": SERVER_TIMESTAMP,
            "updatedAt": SERVER_TIMESTAMP,
        })
    print(f"[Seed] {len(users)} usuarios de demostración insertados en /users")

    # 5. Colección answers (colección raíz con userId)
    answers = [{
        "id": "ans_001",
        "userId": "usr_demo",
        "questionId": "q_lectora_001",
        "selected": "B",
        "correct": True,
        "elapsedMs": 24000,
        "cohortPercentile": 78,
        "answeredAt": SERVER_TIMESTAMP,
    }]
    for a in answers:
        await db.collection(COL.answers).document(a["id"]).set(a)
    print(f"[Seed] {len(answers)} respuestas insertadas en /answers")

    # 6. Colección corrections (colección raíz con userId)
    corrections = [{
        "id": "cor_001",
        "userId": "usr_demo",
        "questionId": "q_lectora_001",
        "reason": "wrong_answer",
        "comment": "La alternativa correcta debería ser C.",
        "status": "pending",
        "potentialReward": {"amount": 250},
        "createdAt": SERVER_TIMESTAMP,
        "reviewedAt": None,
        "reviewedBy": None,
    }]
    for c in corrections:
        await db.collection(COL.corrections).document(c["id"]).set(c)
    print(f"[Seed] {len(corrections)} recorrecciones insertadas en /corrections")

    # 7. Subcolección users/{uid}/medalLedger
    await (db.collection(COL.users).document("usr_demo")
           .collection(COL.medal_ledger).document("ml_001").set({
               "id": "ml_001",
               "type": "answer_correct",
               "tier": "bronze",
               "amount": 1,
               "referenceId": "q_lectora_001",
               "createdAt": SERVER_TIMESTAMP,
           }))
    print("[Seed] 1 movimiento de medalla insertado en users/usr_demo/medalLedger")

    # 8. Documento de estado users/{uid}/state/practice (ADR-09)
    for uid, state in practice_states.items():
        doc = {**state, "lastAnsweredAt": SERVER_TIMESTAMP} if state["answeredQuestionIds"] else state
        await db.collection(COL.users).document(uid).collection(COL.state).document("practice").set(doc)
    print(f"[Seed] Estado de práctica insertado para {' y '.join(practice_states)}")

    print("[Seed] ¡Siembra de datos finalizada con éxito!")
