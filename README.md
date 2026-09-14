# 📊 Amazon Sales Analytics & Operational Performance

Production-ready Data Analytics portfolio project analyzing e-commerce sales transactions from an Amazon seller dataset (~129k rows). The project covers full-stack analytical workflow: data pipeline setup, SQL query development, exploratory data analysis (EDA), and business insights generation.

---

## 🛠️ Tech Stack & Architecture

* **Database:** PostgreSQL running in Docker container
* **Data Processing & ETL:** Python (`Pandas`, `SQLAlchemy`, `psycopg2`)
* **EDA & Visualization:** Jupyter Notebook, `Seaborn`, `Matplotlib`
* **Development Environment:** VS Code, DBeaver, `.env` configuration for credentials management
* **Version Control:** Git / GitHub with Conventional Commits

---

## 📈 Key Business Metrics & Insights (KPIs)

1. **Revenue Drivers (Pareto Analysis):**
   * Sales are heavily concentrated in top categories: **Set** (~35.5M INR) and **Kurta** (~19.3M INR) generate over 75% of total net revenue.
   * Tail categories (*Saree*, *Bottom*, *Dupatta*) contribute less than 1% combined.

2. **Fulfillment Logistics:**
   * **70.7%** of completed orders are fulfilled by Amazon (**FBA**), while **29.3%** are handled directly by the **Merchant (FBM)**.
   * FBA shows higher volume throughput and improved fulfillment reliability.

3. **Revenue Leakage & Order Cancellations:**
   * **18,332 orders** (~14% of overall order volume) were canceled, resulting in ~6.9M INR in lost gross revenue.
   * Average Order Value (AOV) remains stable across all fulfillment statuses at ~640–680 INR.

---

## 📂 Project Structure

```text
e-commerce-amazon/
├── .env.example        # Environment variables template
├── .gitignore          # Excluded sensitive credentials & venv
├── queries.sql         # Production-ready SQL analytical queries
├── eda_analysis.ipynb  # Jupyter Notebook with EDA, visualizations & insights
├── script.py           # Database ingestion & cleaning ETL script
└── README.md           # Project documentation


---

Markdown
## 🚀 How to Run Locally

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/e-commerce-amazon.git
   cd e-commerce-amazon
Configure Environment:
Create a .env file in the root directory using .env.example as a reference:


DB_USER=postgres
DB_PASSWORD=your_password
DB_HOST=localhost
DB_PORT=5432
DB_NAME=salary_db
Set up Virtual Environment & Dependencies:


python -m venv venv
# On Windows: venv\Scripts\activate | On Linux/macOS: source venv/bin/activate
pip install -r requirements.txt
Run PostgreSQL Container & Data Pipeline:

Bash
docker run --name postgres-db -e POSTGRES_PASSWORD=your_password -p 5432:5432 -d postgres
python script.py