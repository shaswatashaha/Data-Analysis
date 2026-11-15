/*
=============================================================================
HEALTH ANALYTICS PROJECT: COVID-19 DATA EXPLORATION & VACCINATION IMPACT
Target Database: PostgreSQL
Skills Demonstrated: DDL/DML Ingestion, Joins, Window Functions, CTEs,
                      Temp Tables, Database Views, Defensive Math (NULLIF/COALESCE),
                      Dynamic Cohort Binning, Data Auditing
=============================================================================
*/

-- =============================================================================
-- SECTION 1: DATABASE SETUP & DATA INGESTION (DDL / DML)
-- =============================================================================


-- Set correct date handling format for day/month/year style entries
SET datestyle = 'ISO, DMY';


-- Drop tables if they already exist to ensure idempotency

DROP TABLE IF EXISTS public.coviddeaths;
DROP TABLE IF EXISTS public.covidvaccinations;

-- Create staging table for clinical records

CREATE TABLE public.coviddeaths (
	iso_code varchar(50) NULL,
	continent varchar(50) NULL,
	"location" varchar(50) NULL,
	"date" date NULL,
	population float8 NULL,
	total_cases float8 NULL,
	new_cases float8 NULL,
	new_cases_smoothed float8 NULL,
	total_deaths float8 NULL,
	new_deaths float8 NULL,
	new_deaths_smoothed float8 NULL,
	total_cases_per_million float8 NULL,
	new_cases_per_million float8 NULL,
	new_cases_smoothed_per_million float8 NULL,
	total_deaths_per_million float8 NULL,
	new_deaths_per_million float8 NULL,
	new_deaths_smoothed_per_million float8 NULL,
	reproduction_rate float8 NULL,
	icu_patients float8 NULL,
	icu_patients_per_million float8 NULL,
	hosp_patients float8 NULL,
	hosp_patients_per_million float8 NULL,
	weekly_icu_admissions float8 NULL,
	weekly_icu_admissions_per_million float8 NULL,
	weekly_hosp_admissions float8 NULL,
	weekly_hosp_admissions_per_million float8 NULL
);


-- Ingest clinical records from CSV source

COPY public.coviddeaths
FROM '../Project/COvid 19/Data/CovidDeaths.csv'
WITH (

    FORMAT CSV,

    HEADER true,

    DELIMITER ',',

    NULL ''

);

-- Create staging table for immunization and testing records

CREATE TABLE public.covidvaccinations (
    iso_code varchar(50) NULL,
    continent varchar(50) NULL,
    location varchar(100) NULL,
    date date NULL,

    new_tests float8 NULL,
    total_tests float8 NULL,
    total_tests_per_thousand float8 NULL,
    new_tests_per_thousand float8 NULL,
    new_tests_smoothed float8 NULL,
    new_tests_smoothed_per_thousand float8 NULL,
    positive_rate float8 NULL,
    tests_per_case float8 NULL,

    tests_units varchar(100) NULL,

    total_vaccinations float8 NULL,
    people_vaccinated float8 NULL,
    people_fully_vaccinated float8 NULL,
    new_vaccinations float8 NULL,
    new_vaccinations_smoothed float8 NULL,

    total_vaccinations_per_hundred float8 NULL,
    people_vaccinated_per_hundred float8 NULL,
    people_fully_vaccinated_per_hundred float8 NULL,
    new_vaccinations_smoothed_per_million float8 NULL,

    stringency_index float8 NULL,
    population_density float8 NULL,
    median_age float8 NULL,
    aged_65_older float8 NULL,
    aged_70_older float8 NULL,
    gdp_per_capita float8 NULL,
    extreme_poverty float8 NULL,
    cardiovasc_death_rate float8 NULL,
    diabetes_prevalence float8 NULL,
    female_smokers float8 NULL,
    male_smokers float8 NULL,
    handwashing_facilities float8 NULL,
    hospital_beds_per_thousand float8 NULL,
    life_expectancy float8 NULL,
    human_development_index float8 NULL
);



-- Ingest immunization records from CSV source

COPY public.covidvaccinations
FROM '../CovidVaccinations.csv'
WITH (
    FORMAT CSV,
    HEADER true,
    DELIMITER ',',
    NULL ''
);

-- =============================================================================
-- SECTION 2: BASELINE EXPLORATORY DATA ANALYSIS (EDA)
-- =============================================================================


-- Quick sanity check on ingested datasets
SELECT * FROM public.coviddeaths WHERE continent IS NOT NULL ORDER BY location, date LIMIT 100;
SELECT * FROM public.covidvaccinations WHERE continent IS NOT NULL ORDER BY location, date LIMIT 100;



-- Extract primary metrics baseline ordered by country and timeline
SELECT 
    location, 
    date, 
    total_cases, 
    new_cases, 
    total_deaths, 
    population
FROM public.coviddeaths
WHERE continent IS NOT NULL 
ORDER BY location, date;


-- Total Cases vs Total Deaths
-- Shows likelihood of dying if you contract covid in United States

SELECT 
    location, 
    date, 
    population, 
    total_cases,  
    ROUND(((total_cases / NULLIF(population, 0)) * 100)::numeric, 2) AS percent_population_infected
FROM coviddeaths
ORDER BY location, date;


-- Total Cases vs Population
-- Shows what percentage of population infected with Covid

SELECT 
    location, 
    date, 
    population, 
    total_cases,  
    ROUND(((total_cases / NULLIF(population, 0)) * 100)::numeric, 2) AS percent_population_infected
FROM public.coviddeaths
ORDER BY location, date;


-- Country Rank: Highest infection penetration relative to population scale
SELECT 
    location, 
    population, 
    MAX(total_cases) AS highest_infection_count,  
    ROUND((MAX(total_cases) / NULLIF(population, 0) * 100)::numeric, 2) AS percent_population_infected
FROM public.coviddeaths
GROUP BY location, population
ORDER BY percent_population_infected DESC;






-- Showing countries with highest Death Count per Population

SELECT 
    location, 
    MAX(total_deaths) AS total_death_count
FROM coviddeaths 
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY total_death_count DESC;


-- BREAKING THINGS DOWN BY CONTINENT

-- Showing contintents with the highest death count per population


select continent, Max(total_deaths) as TotalDeathCount
from coviddeaths 
where continent is not Null
group by continent
order by TotalDeathCount desc;


-- Global COVID-19 Case and Mortality Summary

SELECT
    SUM(new_cases) AS total_cases,
    SUM(new_deaths) AS total_deaths,
    ROUND(
        (SUM(new_deaths) * 100.0 / NULLIF(SUM(new_cases), 0))::numeric,
        2
    ) AS death_percentage
FROM coviddeaths
WHERE continent IS NOT NULL;



-- =============================================================================
-- SECTION 3: CORE DATA PIPELINE STRUCTURES (CTEs, TEMP TABLES, VIEWS)
-- =============================================================================

-- Looking at total Population vs Vaccinations
-- Shows Percentage of Population that has recieved at least one Covid Vaccine

SELECT 
    dea.continent, 
    dea.location, 
    dea.date, 
    dea.population, 
    vac.new_vaccinations,
    SUM(vac.new_vaccinations) OVER (
        PARTITION BY dea.location 
        ORDER BY dea.date
    ) AS rolling_people_vaccinated
FROM coviddeaths dea 
JOIN covidvaccinations vac
  ON dea.location = vac.location 
 AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
ORDER BY dea.location, dea.date;



-- Using CTE to perform Calculation on Partition By in previous query

WITH pop_vs_vac AS (
    SELECT 
        dea.continent, 
        dea.location, 
        dea.date, 
        dea.population, 
        vac.new_vaccinations,
        SUM(vac.new_vaccinations) OVER (
            PARTITION BY dea.location 
            ORDER BY dea.date
        ) AS rolling_people_vaccinated
    FROM public.coviddeaths dea 
    JOIN public.covidvaccinations vac
      ON dea.location = vac.location 
     AND dea.date = vac.date
    WHERE dea.continent IS NOT NULL
)
SELECT 
    *, 
    ROUND(((rolling_people_vaccinated / NULLIF(population, 0)) * 100)::numeric, 4) AS rolling_vaccination_percentage 
FROM pop_vs_vac
ORDER BY location, date;




-- Using Temp Table to perform Calculation on Partition By in previous query


DROP Table if exists public.PercentPopulationVaccinated;

CREATE TABLE public.PercentPopulationVaccinated
(
    Continent Varchar(50),
    Location  varchar(100),
    date      DATE NULL,
    Population float8 NULL,
    New_vaccinations float8 NULL,
    RollingPeopleVaccinated float8 NULL
)

INSERT INTO public.percentpopulationvaccinated
(
    continent,
    location,
    date,
    population,
    new_vaccinations,
    rollingpeoplevaccinated
)
SELECT 
    dea.continent,
    dea.location,
    dea.date,
    dea.population,
    vac.new_vaccinations,

    SUM(vac.new_vaccinations) OVER (
        PARTITION BY dea.location 
        ORDER BY dea.date
    ) AS RollingPeopleVaccinated

FROM coviddeaths dea

JOIN covidvaccinations vac
ON dea.location = vac.location
AND dea.date = vac.date

WHERE dea.continent IS NOT NULL;


SELECT
    *,
    ROUND(
        (RollingPeopleVaccinated * 100.0 / NULLIF(population, 0))::numeric,
        2
    ) AS rolling_vaccination_percentage
FROM percentpopulationvaccinated;


-- Creating View to store data for later visualizations

CREATE OR REPLACE VIEW public.view_percent_population_vaccinated AS 
SELECT 
    dea.continent, 
    dea.location, 
    dea.date, 
    dea.population, 
    vac.new_vaccinations,
    SUM(vac.new_vaccinations) OVER (
        PARTITION BY dea.location 
        ORDER BY dea.date
    ) AS rolling_people_vaccinated
FROM public.coviddeaths dea 
JOIN public.covidvaccinations vac
  ON dea.location = vac.location 
 AND dea.date = vac.date
WHERE dea.continent IS NOT NULL;

select * from PercentPopulationVaccinated;

-- =============================================================================
-- SECTION 4: ADVANCED HEALTHCARE & OPERATIONAL ANALYTICS
-- =============================================================================


-- Signal Smoothing: 7-Day Rolling Moving Average to identify true epidemiological waves

SELECT 
    location,
    date,
    new_cases,
    ROUND(AVG(new_cases) OVER (
        PARTITION BY location
        ORDER BY date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    )::numeric, 2) AS seven_day_avg,
    LAG(new_cases, 7) OVER (
        PARTITION BY location
        ORDER BY date
    ) AS cases_last_week
FROM public.coviddeaths
WHERE continent IS NOT NULL
ORDER BY location, date;




-- Case Fatality Rate (CFR) Trajectory & Wave Severity Analysis
-- Severity Trends: Comparing Cumulative Macro Baseline vs. Real-Time 30-Day Incident CFR to isolate saturation signatures

SELECT
    location,
    date,

    -- 1. Cumulative Case Fatality Rate (%) - Macro Baseline
    ROUND(
        (
            total_deaths::numeric
            / NULLIF(total_cases::numeric, 0)
        ) * 100,
        2
    ) AS cumulative_cfr,

    -- 2. Rolling 30-Day Reported Case Fatality Rate (%) - Real-Time Wave Severity
    ROUND(
        (
            SUM(new_deaths) OVER (
                PARTITION BY location
                ORDER BY date
                ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
            )::numeric
            /
            NULLIF(
                SUM(new_cases) OVER (
                    PARTITION BY location
                    ORDER BY date
                    ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
                )::numeric,
                0
            )
        ) * 100,
        2
    ) AS rolling_30d_cfr

FROM public.coviddeaths
WHERE continent IS NOT NULL
  AND total_cases > 0
ORDER BY location, date;



-- Did vaccination reduce deaths?
-- Direct Impact Test: Broad Pre vs. Post Vaccination Mortality Shift Evaluation


WITH vaccination_impact AS (
    SELECT
        dea.location,
        dea.new_deaths_per_million, 
        vac.people_vaccinated_per_hundred
    FROM public.coviddeaths dea
    JOIN public.covidvaccinations vac
        ON dea.location = vac.location
        AND dea.date = vac.date
    WHERE dea.continent IS NOT NULL
      AND vac.people_vaccinated_per_hundred IS NOT NULL
)
SELECT
    location,
    ROUND(AVG(CASE WHEN people_vaccinated_per_hundred < 20.0 THEN new_deaths_per_million END)::numeric, 2) AS avg_deaths_low_vaccination,
    ROUND(AVG(CASE WHEN people_vaccinated_per_hundred >= 60.0 THEN new_deaths_per_million END)::numeric, 2) AS avg_deaths_high_vaccination
FROM vaccination_impact
GROUP BY location
ORDER BY avg_deaths_low_vaccination DESC NULLS LAST;






-- Hospital capacity vs COVID patients
-- Resource Optimization: ICU Rate and Relative Hospital Capacity Strain Ranking




SELECT
    location,
    date,
    hosp_patients,
    hosp_patients_per_million,
    icu_patients,
    icu_patients_per_million,
    new_cases,
    
    -- Cast the entire percentage expression to ::numeric so ROUND(numeric, int) matches
    ROUND(
        ((icu_patients::numeric / NULLIF(hosp_patients, 0)) * 100)::numeric, 
        2
    ) AS icu_acuity_rate_pct,
    
    DENSE_RANK() OVER (
        PARTITION BY date
        ORDER BY hosp_patients_per_million DESC
    ) AS per_capita_hospital_stress_rank

FROM public.coviddeaths
WHERE continent IS NOT NULL
  AND hosp_patients_per_million IS NOT NULL
ORDER BY date, per_capita_hospital_stress_rank;

/*
Query Name: Clinical Severity Metrics Across Vaccination Coverage Bands
Objective: Aggregate daily country-level health metrics (hospitalizations, 
mortality, and case fatality rate) into progressive vaccination tiers. 
Methodology: Utilizes PostgreSQL FILTER clauses to enforce symmetrical 
sampling for the case fatality rate, ensuring ratios are only calculated 
on days with matched case/death reporting to prevent denominator skew.
*/



WITH banded_data AS (

    SELECT
        dea.location,
        dea.date,

        -- Classify observations by vaccination coverage
        CASE
            WHEN vac.people_vaccinated_per_hundred < 10
                THEN 'Below 10%'
            WHEN vac.people_vaccinated_per_hundred < 20
                THEN '10%-<20%'
            WHEN vac.people_vaccinated_per_hundred < 30
                THEN '20%-<30%'
            WHEN vac.people_vaccinated_per_hundred < 40
                THEN '30%-<40%'
            WHEN vac.people_vaccinated_per_hundred < 50
                THEN '40%-<50%'
            WHEN vac.people_vaccinated_per_hundred < 60
                THEN '50%-<60%'
            ELSE '60% or higher'
        END AS vaccination_coverage_band,

        -- Numeric sorting order
        CASE
            WHEN vac.people_vaccinated_per_hundred < 10 THEN 1
            WHEN vac.people_vaccinated_per_hundred < 20 THEN 2
            WHEN vac.people_vaccinated_per_hundred < 30 THEN 3
            WHEN vac.people_vaccinated_per_hundred < 40 THEN 4
            WHEN vac.people_vaccinated_per_hundred < 50 THEN 5
            WHEN vac.people_vaccinated_per_hundred < 60 THEN 6
            ELSE 7
        END AS sort_order,

        dea.hosp_patients_per_million,
        dea.new_deaths_per_million,
        dea.new_deaths,
        dea.new_cases

    FROM public.coviddeaths dea

    JOIN public.covidvaccinations vac
      ON dea.location = vac.location
     AND dea.date = vac.date

    WHERE dea.continent IS NOT NULL
      AND vac.people_vaccinated_per_hundred IS NOT NULL
)

SELECT
    vaccination_coverage_band,

    -- Number of country-date observations
    COUNT(*) AS country_day_observations,

    -- Number of distinct countries
    COUNT(DISTINCT location) AS countries_included,

    -- Average hospitalization burden
    COUNT(hosp_patients_per_million)
        AS hospitalization_observations,

    ROUND(
        AVG(hosp_patients_per_million)::numeric,
        2
    ) AS avg_hospital_patients_per_million,

    -- Average reported daily mortality
    COUNT(new_deaths_per_million)
        AS mortality_observations,

    ROUND(
        AVG(new_deaths_per_million)::numeric,
        2
    ) AS avg_daily_deaths_per_million,

    -- Number of matched case-death observations
    COUNT(*) FILTER (
        WHERE new_deaths IS NOT NULL
          AND new_cases IS NOT NULL
    ) AS paired_case_death_observations,

    -- Aggregate reported deaths-to-cases ratio
    ROUND(
        (
            (SUM(new_deaths) FILTER (
                WHERE new_deaths IS NOT NULL
                  AND new_cases IS NOT NULL
            ))::numeric
            /
            NULLIF(
                (SUM(new_cases) FILTER (
                    WHERE new_deaths IS NOT NULL
                      AND new_cases IS NOT NULL
                ))::numeric,
                0
            )
        ) * 100,
        2
    ) AS aggregate_reported_deaths_to_cases_pct

FROM banded_data

GROUP BY
    sort_order,
    vaccination_coverage_band

ORDER BY sort_order;







