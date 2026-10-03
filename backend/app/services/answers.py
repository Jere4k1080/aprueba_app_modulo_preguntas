"""Registro de la respuesta del alumno: POST /questions/{id}/answer (HU-03, T-28, T-29, HT-04 y T-30; ADR-86 y
ADR-87)."""
import secrets
from datetime import datetime, timezone

from google.cloud import firestore
from google.cloud.firestore import DELETE_FIELD, SERVER_TIMESTAMP, ArrayUnion, Increment

from app.core.errors import ApiError
from app.db.firestore import COL
from app.services.practice import day_quota, load_plan, pending_id, practice_state, quota_meta
from app.services.questions import cohort_percentile, elapsed_bucket, short_explanation

LETTERS = "ABCDE"


def skill_mastery(correct: int, total: int, max_level: int) -> dict:
    """Dominio de una habilidad (ADR-69, propuesta): el nivel es el número de aciertos con tope en maxLevel y el
    estado pasa a mastered al llegar al tope. Lo usan la respuesta y el seed."""
    level = min(max_level, correct)
    return {"correct": correct, "total": total, "percent": round(100 * correct / total), "level": level,
            "status": "mastered" if level == max_level else "in_progress"}


async def register_answer(db, student: dict, question_id: str, selected: str) -> dict:
    """Registra la respuesta a la pregunta pendiente en una sola transacción (ADR-86).

    Validaciones, en orden: solo se responde la pendiente, y cualquier otra pregunta da NOT_FOUND sin confirmar
    si existe; una ya respondida da ALREADY_ANSWERED; la letra debe existir en la pregunta (A a D con cuatro
    alternativas, A a E con cinco); y la cuota del día, reiniciada si cambió el día, no debe estar en su tope.
    El tiempo es la hora de la API menos deliveredAt (T-28): el elapsedMs que mande la app no se usa."""
    user_ref = db.collection(COL.users).document(student["id"])
    state_ref = practice_state(db, student["id"])

    @firestore.async_transactional
    async def responder(tx):
        state = (await state_ref.get(transaction=tx)).to_dict() or {}
        if question_id in (state.get("answeredQuestionIds") or []):
            raise ApiError(409, "ALREADY_ANSWERED")
        if question_id != pending_id(state):
            raise ApiError(404, "NOT_FOUND")
        question_ref = db.collection(COL.questions).document(question_id)
        answer_ref = user_ref.collection(COL.answers).document(question_id)
        question_snap = await question_ref.get(transaction=tx)
        if (await answer_ref.get(transaction=tx)).exists:
            raise ApiError(409, "ALREADY_ANSWERED")
        question = question_snap.to_dict() if question_snap.exists else None
        if not question or question.get("status") != "published":
            raise ApiError(404, "NOT_FOUND")
        if selected not in set(LETTERS[:len(question.get("options") or [])]):
            raise ApiError(400, "INVALID_OPTION")

        user = (await user_ref.get(transaction=tx)).to_dict() or {}
        # Lectura fuera de la transacción: la consola cambia los planes muy de vez en cuando.
        plan = await load_plan(db, user.get("plan") or "free")
        quota = day_quota(user.get("quota"), plan)
        if not quota.get("unlimited") and quota.get("used", 0) >= quota.get("max", 0):
            raise ApiError(422, "QUOTA_DAILY_LIMIT")

        skill_id = question.get("skillId")
        skill = (await db.collection(COL.skills).document(skill_id).get(transaction=tx)).to_dict() if skill_id else None
        mastery_ref = user_ref.collection(COL.skill_mastery).document(skill_id) if skill else None
        mastery = ((await mastery_ref.get(transaction=tx)).to_dict() or {}) if skill else {}

        delivered = state.get("deliveredAt")
        # Sin deliveredAt (pendiente entregada antes de T-28) no hay tiempo que medir: no entra al histograma.
        elapsed = max(1, int((datetime.now(timezone.utc) - delivered).total_seconds() * 1000)) if delivered else None
        percentile = cohort_percentile((question.get("stats") or {}).get("elapsedBuckets"), elapsed) if elapsed else None
        correct = selected == question.get("correctAnswer")
        amount = (plan.get("badges") or {}).get("correct", 0) if correct else 0
        quota["used"] = quota.get("used", 0) + 1

        tx.create(answer_ref, {
            "questionId": question_id, "testId": question.get("testId"), "axis": question.get("axis"),
            "skillId": skill_id, "selected": selected, "correct": correct, "elapsedMs": elapsed,
            "cohortPercentile": percentile, "difficulty": question.get("difficulty"), "answeredAt": SERVER_TIMESTAMP,
        })
        user_update = {"quota": quota}
        if amount:
            user_update.update({"medalWallet.bronze": Increment(amount), "badgesTotal": Increment(amount)})
            tx.create(db.collection(COL.medal_transactions).document(f"mtx_{secrets.token_hex(5)}"), {
                "userId": student["id"], "tier": "bronze", "amount": amount, "reason": "answer_correct",
                "refId": question_id, "at": SERVER_TIMESTAMP,
            })
        tx.update(user_ref, user_update)
        if elapsed:
            tx.update(question_ref, {
                "stats.timesAnswered": Increment(1), "stats.timesCorrect": Increment(int(correct)),
                "stats.sumElapsedMs": Increment(elapsed), f"stats.elapsedBuckets.{elapsed_bucket(elapsed)}": Increment(1),
            })
        tx.update(state_ref, {"answeredQuestionIds": ArrayUnion([question_id]), "lastQuestionId": DELETE_FIELD,
                              "deliveredAt": DELETE_FIELD, "lastAnsweredAt": SERVER_TIMESTAMP})
        if skill:
            tx.set(mastery_ref, {
                "testId": question.get("testId"),
                **skill_mastery(mastery.get("correct", 0) + int(correct), mastery.get("total", 0) + 1,
                                skill.get("maxLevel") or 1),
                "updatedAt": SERVER_TIMESTAMP,
            })
        return {
            "correct": correct,
            "correctAnswer": question.get("correctAnswer"),
            "shortExplanation": short_explanation(question.get("explanation")),
            "cohortPercentile": percentile,
            "medalAwarded": {"tier": "bronze", "amount": amount} if amount else None,
            "quota": quota_meta(quota)["quota"],
        }

    return await responder(db.transaction())
