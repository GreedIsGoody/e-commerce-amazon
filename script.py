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

df.to_sql('amazon_sales', engine, if_exists='append', index=False)
print(f"Success! Loaded {len(df)} lines.")