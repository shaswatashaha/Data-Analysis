# Data Analysis Portfolio

A curated portfolio of end-to-end data analysis projects transforming raw, multi-table datasets into structured SQL queries, reproducible Python workflows, and clear visual narratives.

## Projects

| Project | Focus & Analytical Scope | Tools & Methods |
| :--- | :--- | :--- |
| **COVID-19** | Exploratory analysis of country-level pandemic data (Jan 2020 – Apr 2021), evaluating 7-day case trajectories, week-over-week wave momentum, rolling vs. cumulative fatality ratios, vaccination-coverage bands, and daily cross-country hospitalization rankings. | **PostgreSQL** (`AVG()`, `SUM()`, `DENSE_RANK()`, `FILTER`, `NULLIF()`), **Python**, **Pandas**, **NumPy**, **SQLAlchemy**, **Plotly** |

---

## Repository Structure

Each project lives in its own self-contained directory with dedicated SQL scripts, notebooks, datasets, static chart exports, and a detailed analytical README:

```text
Data-Analysis/
├── COvid 19/         # Epidemiological trends, CFR trajectories, and hospital burden rankings
└── README.md         # Portfolio overview and project index
