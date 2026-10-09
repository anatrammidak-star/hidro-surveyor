# SiCA AI Backend v1

Backend awal untuk aplikasi SiCA - Survei Cepat Air.

## Tujuan

- Menyediakan REST API.
- Memvalidasi kontrak data survei versi 1.0.
- Menyiapkan fondasi perhitungan fisika.
- Mencegah keluaran prediksi AI palsu sebelum vision engine tersedia.

## Endpoint

- `GET /health`
- `POST /api/v1/analyze`

## Menjalankan secara lokal

Dari direktori `ai_backend`:

```bash
python -m venv .venv
```

Aktifkan virtual environment, lalu:

```bash
pip install -r requirements.txt
uvicorn app.main:app --reload
```

Buka dokumentasi API di `/docs`.

## Menjalankan pengujian

```bash
pytest -q
```

## Status

Vision engine masih placeholder. API belum terhubung dengan aplikasi Flutter maupun server produksi.
