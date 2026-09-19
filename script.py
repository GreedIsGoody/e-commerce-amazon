import os
import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine

load_dotenv()

engine = create_engine(
    f"postgresql://{os.getenv('DB_USER')}:{os.getenv('DB_PASSWORD')}@"
    f"{os.getenv('DB_HOST')}:{os.getenv('DB_PORT')}/{os.getenv('DB_NAME')}"
)

df = pd.read_csv('Amazon Sale Report.csv', low_memory=False)

df.columns = (
    df.columns
    .str.strip()
    .str.lower()
    .str.replace(':', '')
    .str.replace('-', '_')
    .str.replace(' ', '_')
)

df['date'] = pd.to_datetime(df['date'], format='%m-%d-%y', errors='coerce')
#Remove technical / empy columns
df = df.drop(columns=['index', 'unnamed_22'], errors='ignore')

text_columns = [
    'status', 'fulfilment', 'category',
    'sales_channel', 'ship_service_level'
]

for column in text_columns:
    if column in df.columns:
        df[column] = df[column].str.strip()
        
df['amount'] = pd.to_numeric(df['amount'], errors='coerce')
df['qty'] = pd.to_numeric(df['qty'], errors='coerce').fillna(0).astype(int)

print(f"Rows: {len(df):,}")
print(f"Unique orders: {df['order_id'].nunique():,}")
print(f"Missing amount: {df['amount'].isna().sum():,}")
print(f"Duplicate rows: {df.duplicated().sum():,}")

df.to_sql('amazon_sales', engine, if_exists='replace', index=False)
print(f"Success! Loaded {len(df)} lines.")