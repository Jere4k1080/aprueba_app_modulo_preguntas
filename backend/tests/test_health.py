"""Port de backend/test/health.test.js: las diez pruebas, una función por prueba."""
import asyncio
import base64
import json
import os
import re
from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient

import app.db.firestore as firestore_db
import app.seed as seed
from app.core.config import get_settings
from app.core.errors import ERROR_STATUS, MESSAGES, ApiError
from app.main import app, create_app
from app.services.questions import calculate_cohort_percentile, sanitize_question

client = TestClient(app)


def test_01_sanitize_question_elimina_correct_answer_y_explanation():
    raw = {
        "id": "q_test_01",
        "statement": "¿Cuál es la capital de Chile?",
        "options": ["Santiago", "Lima", "Bogotá", "Buenos Aires"],
        "correctAnswer": "A",
        "explanation": "Santiago fue fundada en 1541...",
    }
    sanitized = sanitize_question(raw)
    assert sanitized["id"] == "q_test_01"
    assert "correctAnswer" not in sanitized
    assert "explanation" not in sanitized
    assert raw["correctAnswer"] == "A", "el objeto original no debe mutar"
    assert sanitize_question(None) is None


def test_02_calculate_cohort_percentile():
    thresholds = {"p25": 15000, "p50": 25000, "p75": 45000, "p90": 60000}
    assert calculate_cohort_percentile(thresholds, 10000) == 90
    assert calculate_cohort_percentile(thresholds, 20000) == 75
    assert calculate_cohort_percentile(thresholds, 40000) == 50
    assert calculate_cohort_percentile(thresholds, 55000) == 25
    assert calculate_cohort_percentile(thresholds, 70000) == 10
    assert calculate_cohort_percentile(None, 10000) == 50
    assert calculate_cohort_percentile(thresholds, "10000") == 50
    # Un documento mal cargado no revienta: umbral nulo o de texto toma su valor por defecto.
    assert calculate_cohort_percentile({**thresholds, "p25": None}, 10000) == 90
    assert calculate_cohort_percentile({"p90": "60000"}, 59000) == 25
    assert calculate_cohort_percentile(0, 10000) == 50


def test_03_catalogo_de_errores():
    err = ApiError(422, "QUOTA_BASE_REACHED")
    assert (err.status, err.code) == (422, "QUOTA_BASE_REACHED")
    # Como AppError en Node, un código del catálogo no puede salir con otro status.
    with pytest.raises(ValueError, match="QUOTA_BASE_REACHED va con status 422"):
        ApiError(400, "QUOTA_BASE_REACHED")
    assert ERROR_STATUS["QUOTA_DAILY_LIMIT"] == 422
    assert ERROR_STATUS["NOT_FOUND"] == 404
    assert set(MESSAGES) == set(ERROR_STATUS)
    for code, textos in MESSAGES.items():
        assert textos.get("es") and textos.get("en"), f"{code}: falta es o en"


def test_04_health_responde_envelope_con_request_id():
    res = client.get("/api/v1/health")
    assert res.status_code == 200
    body = res.json()
    assert body["error"] is None
    assert re.fullmatch(r"req_[0-9a-f]{12}", body["meta"]["requestId"])
    assert res.headers["x-request-id"] == body["meta"]["requestId"]
    assert re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z", body["meta"]["timestamp"])
    data = body["data"]
    assert data["status"] == "ok"
    assert data["service"] == "aprueba-questions-backend"
    assert data["version"] == "1.0.0"
    assert data["environment"] == "local"
    assert isinstance(data["uptimeSeconds"], int)


def test_05_ruta_inexistente_da_404_not_found():
    res = client.get("/api/v1/unknown-endpoint")
    assert res.status_code == 404
    body = res.json()
    assert body["data"] is None
    assert body["error"]["code"] == "NOT_FOUND"
    assert body["error"]["details"] == []
    assert body["meta"]["requestId"].startswith("req_")


def test_06_cors_lista_exacta_patron_y_solicitud_previa():
    def origin_of(res):
        return res.headers.get("access-control-allow-origin")

    ok = client.get("/api/v1/health", headers={"Origin": "https://app.aprueba.test"})
    assert origin_of(ok) == "https://app.aprueba.test"
    preview = client.get("/api/v1/health", headers={"Origin": "https://aprueba-pr-12.vercel.app"})
    assert origin_of(preview) == "https://aprueba-pr-12.vercel.app"
    denied = client.get("/api/v1/health", headers={"Origin": "https://app.aprueba.test.evil.example"})
    assert origin_of(denied) is None

    preflight = client.options("/api/v1/health", headers={
        "Origin": "https://app.aprueba.test",
        "Access-Control-Request-Method": "GET",
        "Access-Control-Request-Headers": "Authorization",
    })
    # Starlette responde 200 a la solicitud previa permitida; Express respondía 204.
    assert preflight.status_code == 200
    assert origin_of(preflight) == "https://app.aprueba.test"
    assert "access-control-allow-credentials" not in preflight.headers
    assert "authorization" in preflight.headers["access-control-allow-headers"].lower()

    # La solicitud previa de un origen no permitido recibe 400 en texto plano y sin cabecera de origen.
    rejected = client.options("/api/v1/health", headers={
        "Origin": "https://app.aprueba.test.evil.example",
        "Access-Control-Request-Method": "GET",
    })
    assert rejected.status_code == 400
    assert origin_of(rejected) is None


def test_07_credenciales_de_firestore(monkeypatch):
    creados = []
    monkeypatch.setattr(firestore_db, "AsyncClient", lambda **kw: creados.append(kw) or kw)
    monkeypatch.setattr(firestore_db, "service_account", SimpleNamespace(Credentials=SimpleNamespace(
        from_service_account_info=lambda info: {"project_id": info["project_id"]})))

    def abrir(**env):
        for name in ("FIRESTORE_EMULATOR_HOST", "FIREBASE_SERVICE_ACCOUNT_BASE64", "FIREBASE_PROJECT_ID"):
            if name in env:
                monkeypatch.setenv(name, env[name])
            else:
                monkeypatch.delenv(name, raising=False)
        get_settings.cache_clear()
        monkeypatch.setattr(firestore_db, "_client", None)
        creados.clear()
        firestore_db.get_db()
        firestore_db.get_db()
        return list(creados)

    # El emulador tiene prioridad aunque el base64 sea inválido, y el cliente se crea una sola vez.
    assert abrir(FIRESTORE_EMULATOR_HOST="127.0.0.1:8080", FIREBASE_SERVICE_ACCOUNT_BASE64="invalid") == [
        {"project": "aprueba-dev"}]

    cuenta = base64.b64encode(json.dumps({"project_id": "aprueba-test", "k": ">>>???x"}).encode()).decode()
    sin_relleno, url_segura = cuenta.rstrip("="), cuenta.replace("+", "-").replace("/", "_")
    assert cuenta not in (sin_relleno, url_segura)
    # Como Buffer.from(x, 'base64') de Node: con relleno, sin relleno y con alfabeto URL seguro.
    for valor in (cuenta, sin_relleno, url_segura):
        assert abrir(FIREBASE_SERVICE_ACCOUNT_BASE64=valor) == [
            {"project": "aprueba-test", "credentials": {"project_id": "aprueba-test"}}]
    # Vacía cuenta como ausente, y se retira para que la librería no entre en modo emulador.
    assert abrir(FIRESTORE_EMULATOR_HOST="", FIREBASE_SERVICE_ACCOUNT_BASE64=cuenta) == [
        {"project": "aprueba-test", "credentials": {"project_id": "aprueba-test"}}]
    assert "FIRESTORE_EMULATOR_HOST" not in os.environ

    with pytest.raises(RuntimeError, match="no contiene un JSON válido"):
        abrir(FIREBASE_SERVICE_ACCOUNT_BASE64="invalid")
    with pytest.raises(RuntimeError, match="Configura FIRESTORE_EMULATOR_HOST o FIREBASE_SERVICE_ACCOUNT_BASE64"):
        abrir()


def test_08_produccion_sin_jwt_secret_no_arranca(monkeypatch):
    monkeypatch.setenv("APP_ENV", "production")
    monkeypatch.delenv("JWT_SECRET", raising=False)
    with pytest.raises(RuntimeError, match="JWT_SECRET es obligatorio en producción."):
        create_app()
    monkeypatch.setenv("JWT_SECRET", "   ")
    get_settings.cache_clear()
    with pytest.raises(RuntimeError, match="JWT_SECRET es obligatorio en producción."):
        get_settings()
    # Fuera de producción se usa el mismo valor de desarrollo que tenía Node.
    monkeypatch.setenv("APP_ENV", "local")
    monkeypatch.delenv("JWT_SECRET")
    get_settings.cache_clear()
    assert get_settings().jwt_secret == "dev_jwt_secret_change_in_production_min_32_chars"


def test_09_seed_remoto_exige_seed_allow_remote(monkeypatch):
    monkeypatch.delenv("FIRESTORE_EMULATOR_HOST")
    monkeypatch.delenv("SEED_ALLOW_REMOTE", raising=False)
    abiertos = []
    monkeypatch.setattr(seed, "get_db", lambda: abiertos.append(1))
    with pytest.raises(RuntimeError, match="Seed remoto bloqueado"):
        asyncio.run(seed.seed_database())
    assert abiertos == [], "no debe abrir Firestore antes de verificar el permiso"


def test_10_banco_de_demostracion_consistente():
    tests, skills, questions = seed.load("tests"), seed.load("skills"), seed.load("questions")
    users, practice_states = seed.load("users"), seed.load("practice_states")

    test_ids = {t["id"] for t in tests}
    skill_by_id = {s["id"]: s for s in skills}
    question_ids = {q["id"] for q in questions}
    assert len(skill_by_id) == len(skills), "Hay IDs de habilidades repetidos"
    assert len(question_ids) == len(questions), "Hay IDs de preguntas repetidos"
    for s in skills:
        assert s["isDemo"] and s["testId"] in test_ids, f"{s['id']}: marca de demostración o prueba inválida"
        for p in s["prerequisiteIds"]:
            assert p in skill_by_id and p != s["id"], f"{s['id']}: prerrequisito inválido {p}"

    celdas = set()
    for q in questions:
        assert q["isDemo"] and q["testId"] in test_ids and q["difficulty"] in ("d1", "d2", "d3", "d4"), \
            f"{q['id']}: marca, prueba o dificultad inválida"
        assert 4 <= len(q["options"]) <= 5, f"{q['id']}: debe tener 4 o 5 alternativas"
        assert len(set(q["options"])) == len(q["options"]), f"{q['id']}: alternativas repetidas"
        assert q["correctAnswer"] in "ABCDE"[:len(q["options"])], f"{q['id']}: correctAnswer fuera de las alternativas"
        assert skill_by_id.get(q["skillId"], {}).get("testId") == q["testId"], \
            f"{q['id']}: skillId inexistente o de otra prueba"
        t = q["cohortSpeedThresholds"]
        assert t["p25"] < t["p50"] < t["p75"] < t["p90"], f"{q['id']}: umbrales de rapidez no crecientes"
        assert q["explanation"], f"{q['id']}: falta la explicación"
        celdas.add(f"{q['testId']}/{q['difficulty']}")
    assert len(celdas) == 20, "Faltan preguntas en alguna combinación de prueba y dificultad"

    user_ids = {u["id"] for u in users}
    assert set(practice_states) <= user_ids, "Estado de práctica sin usuario"
    for u in users:
        quota = u["quota"]
        assert all(t in test_ids for t in u["selectedTests"]), f"{u['id']}: prueba seleccionada inexistente"
        assert u["practiceFormat"] in ("random", "facsim") and u["difficulty"] in ("d1", "d2", "d3", "d4"), \
            f"{u['id']}: preferencias inválidas"
        assert quota["used"] <= quota["max"] and all(
            isinstance(quota[b], bool) for b in ("bonusSchool", "bonusAddress", "unlimited")), f"{u['id']}: cuota inválida"
        respondidas = practice_states.get(u["id"], {}).get("answeredQuestionIds", [])
        assert all(i in question_ids for i in respondidas), f"{u['id']}: responde preguntas inexistentes"
        pendientes = [q for q in questions if q["testId"] in u["selectedTests"] and q["id"] not in respondidas]
        assert pendientes, f"{u['id']}: no le quedan preguntas por responder en sus pruebas"

    nuevo = next(u for u in users if u["id"] == "usr_demo_nuevo")
    assert nuevo["quota"] == {"used": 0, "max": 10, "bonusSchool": False, "bonusAddress": False, "unlimited": False}
    assert practice_states["usr_demo_nuevo"]["answeredQuestionIds"] == []
