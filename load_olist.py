import os
import json
import subprocess
import tempfile
import psycopg2
from pathlib import Path

# ── Kaggle ───────────────────────────────────────────────────────────────────
KAGGLE_USERNAME = os.getenv("KAGGLE_USERNAME", "your_username")
KAGGLE_KEY      = os.getenv("KAGGLE_KEY",      "your_key")
KAGGLE_DATASET  = "olistbr/brazilian-ecommerce"

# ── Banco de dados ───────────────────────────────────────────────────────────
DB_HOST     = os.getenv("DB_HOST",     "localhost")
DB_PORT     = os.getenv("DB_PORT",     "5432")
DB_NAME     = os.getenv("DB_NAME",     "postgres")
DB_USER     = os.getenv("DB_USER",     "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "postgres")

# ── Schema ───────────────────────────────────────────────────────────────────
DDL = """
DROP TABLE IF EXISTS order_reviews, order_payments, order_items, orders,
                     product_category_name_translation, sellers, products,
                     geolocation, customers CASCADE;

CREATE TABLE customers (
    customer_id              VARCHAR(50) PRIMARY KEY,
    customer_unique_id       VARCHAR(50),
    customer_zip_code_prefix VARCHAR(10),
    customer_city            VARCHAR(100),
    customer_state           CHAR(2)
);

CREATE TABLE geolocation (
    geolocation_zip_code_prefix VARCHAR(10),
    geolocation_lat             NUMERIC(10,6),
    geolocation_lng             NUMERIC(10,6),
    geolocation_city            VARCHAR(100),
    geolocation_state           CHAR(2)
);

CREATE TABLE products (
    product_id                 VARCHAR(50) PRIMARY KEY,
    product_category_name      VARCHAR(100),
    product_name_lenght        INTEGER,
    product_description_lenght INTEGER,
    product_photos_qty         INTEGER,
    product_weight_g           INTEGER,
    product_length_cm          INTEGER,
    product_height_cm          INTEGER,
    product_width_cm           INTEGER
);

CREATE TABLE sellers (
    seller_id              VARCHAR(50) PRIMARY KEY,
    seller_zip_code_prefix VARCHAR(10),
    seller_city            VARCHAR(100),
    seller_state           CHAR(2)
);

CREATE TABLE product_category_name_translation (
    product_category_name         VARCHAR(100) PRIMARY KEY,
    product_category_name_english VARCHAR(100)
);

CREATE TABLE orders (
    order_id                      VARCHAR(50) PRIMARY KEY,
    customer_id                   VARCHAR(50),
    order_status                  VARCHAR(20),
    order_purchase_timestamp      TIMESTAMP,
    order_approved_at             TIMESTAMP,
    order_delivered_carrier_date  TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP
);

CREATE TABLE order_items (
    order_id            VARCHAR(50),
    order_item_id       INTEGER,
    product_id          VARCHAR(50),
    seller_id           VARCHAR(50),
    shipping_limit_date TIMESTAMP,
    price               NUMERIC(10,2),
    freight_value       NUMERIC(10,2),
    PRIMARY KEY (order_id, order_item_id)
);

CREATE TABLE order_payments (
    order_id             VARCHAR(50),
    payment_sequential   INTEGER,
    payment_type         VARCHAR(20),
    payment_installments INTEGER,
    payment_value        NUMERIC(10,2),
    PRIMARY KEY (order_id, payment_sequential)
);

CREATE TABLE order_reviews (
    review_id               VARCHAR(50),
    order_id                VARCHAR(50),
    review_score            SMALLINT,
    review_comment_title    TEXT,
    review_comment_message  TEXT,
    review_creation_date    TIMESTAMP,
    review_answer_timestamp TIMESTAMP
);
"""

# Mapeamento: tabela → arquivo CSV
CSV_TABLES = [
    ("customers",                         "olist_customers_dataset.csv"),
    ("geolocation",                       "olist_geolocation_dataset.csv"),
    ("products",                          "olist_products_dataset.csv"),
    ("sellers",                           "olist_sellers_dataset.csv"),
    ("product_category_name_translation", "product_category_name_translation.csv"),
    ("orders",                            "olist_orders_dataset.csv"),
    ("order_items",                       "olist_order_items_dataset.csv"),
    ("order_payments",                    "olist_order_payments_dataset.csv"),
    ("order_reviews",                     "olist_order_reviews_dataset.csv"),
]


def configure_kaggle():
    kaggle_dir = Path.home() / ".kaggle"
    kaggle_dir.mkdir(exist_ok=True)
    creds_file = kaggle_dir / "kaggle.json"
    creds_file.write_text(json.dumps({"username": KAGGLE_USERNAME, "key": KAGGLE_KEY}))
    creds_file.chmod(0o600)


def _kaggle_bin() -> str:
    for candidate in ["kaggle", str(Path.home() / ".local/bin/kaggle")]:
        result = subprocess.run(["which", candidate], capture_output=True, text=True)
        if result.returncode == 0:
            return result.stdout.strip()
    raise FileNotFoundError("kaggle CLI não encontrado. Rode: pip install kaggle")


def download_dataset(dest_dir: Path) -> None:
    print(f"Baixando dataset '{KAGGLE_DATASET}'...")
    env = {**os.environ, "KAGGLE_USERNAME": KAGGLE_USERNAME, "KAGGLE_KEY": KAGGLE_KEY}
    subprocess.run(
        [_kaggle_bin(), "datasets", "download",
         "-d", KAGGLE_DATASET, "-p", str(dest_dir), "--unzip"],
        env=env,
        check=True,
    )
    print("Download concluído.")


def load_data(dest_dir: Path) -> None:
    conn = psycopg2.connect(
        host=DB_HOST, port=int(DB_PORT), dbname=DB_NAME,
        user=DB_USER, password=DB_PASSWORD,
    )
    conn.autocommit = False
    cur = conn.cursor()

    print("\nCriando tabelas...")
    cur.execute(DDL)

    for table, filename in CSV_TABLES:
        csv_path = dest_dir / filename
        print(f"  Carregando {table}...", end=" ", flush=True)
        with open(csv_path, encoding="utf-8-sig") as f:
            cur.copy_expert(
                f"COPY {table} FROM STDIN WITH (FORMAT CSV, HEADER true, QUOTE '\"', NULL '')",
                f,
            )
        print(f"{cur.rowcount:,} linhas")

    conn.commit()
    cur.close()
    conn.close()
    print("\nCarga concluída com sucesso.")


def main():
    configure_kaggle()
    with tempfile.TemporaryDirectory() as tmp:
        download_dataset(Path(tmp))
        load_data(Path(tmp))


if __name__ == "__main__":
    main()
