-- **World Life Expectancy Project**

-- **Introduction:**
-- The World Life Expectancy Project explores global trends, determinants, and disparities in life expectancy.
-- This analysis utilizes SQL to clean, analyze, and extract insights from the dataset, highlighting key indicators
-- such as GDP, schooling, immunization rates, and health expenditure.

-- **Sections:**
-- 1. Data Exploration: Understand the dataset structure and identify missing or inconsistent values.
-- 2. Data Cleaning: Correct errors, handle missing data, and prepare the dataset for analysis.
-- 3. Analysis and Insights: Derive trends, rankings, and correlations for meaningful conclusions.

-- **Section 1: Data Exploration**
-- Explore the overall structure and summary of the data
SELECT
    MIN(Year) AS FirstYear,
    MAX(Year) AS LastYear,
    COUNT(DISTINCT Country) AS NumCountries
FROM worldlifexpectancy;

-- Check for missing or null values in critical columns
SELECT
    COUNT(*) AS TotalRecords,
    SUM(CASE WHEN Lifeexpectancy IS NULL OR Lifeexpectancy = '' THEN 1 ELSE 0 END) AS MissingLifeExpectancy,
    SUM(CASE WHEN GDP IS NULL THEN 1 ELSE 0 END) AS MissingGDP
FROM worldlifexpectancy;

-- Analyze data distribution for key metrics
SELECT
    Country,
    AVG(CAST(Lifeexpectancy AS FLOAT)) AS AvgLifeExpectancy,
    AVG(GDP) AS AvgGDP
FROM worldlifexpectancy
GROUP BY Country
ORDER BY AvgLifeExpectancy DESC;

-- **Section 2: Data Cleaning**
-- Correct data types for numerical fields stored as strings
ALTER TABLE worldlifexpectancy
MODIFY COLUMN Lifeexpectancy FLOAT,
MODIFY COLUMN AdultMortality INT,
MODIFY COLUMN infantdeaths INT,
MODIFY COLUMN `under-fivedeaths` INT;

-- Rename the column for consistency
ALTER TABLE worldlifexpectancy
CHANGE `under-fivedeaths` under_fivedeaths INT;

-- Identify and handle negative values
SELECT *
FROM worldlifexpectancy
WHERE Lifeexpectancy < 0 OR AdultMortality < 0 OR infantdeaths < 0 OR under_fivedeaths < 0;

-- Update missing life expectancy with the average value
UPDATE worldlifexpectancy
SET Lifeexpectancy = (SELECT AVG(Lifeexpectancy) FROM worldlifexpectancy WHERE Lifeexpectancy IS NOT NULL)
WHERE Lifeexpectancy IS NULL;

-- Alternatively, remove rows with critical missing information
DELETE FROM worldlifexpectancy
WHERE Lifeexpectancy IS NULL OR GDP IS NULL;

-- Identify duplicate rows
SELECT Row_ID
FROM (
    SELECT ROW_ID,
           CONCAT(Country, Year) AS CompositeKey,
           ROW_NUMBER() OVER (PARTITION BY CONCAT(Country, Year) ORDER BY CONCAT(Country, Year)) AS RowNum
    FROM worldlifexpectancy
) AS RowTable
WHERE RowNum > 1;

-- Remove duplicate rows
DELETE FROM worldlifexpectancy
WHERE ROW_ID IN (
    SELECT Row_ID
    FROM (
        SELECT ROW_ID,
               ROW_NUMBER() OVER (PARTITION BY CONCAT(Country, Year) ORDER BY CONCAT(Country, Year)) AS RowNum
        FROM worldlifexpectancy
    ) AS RowTable
    WHERE RowNum > 1
);

-- Fill missing values for `Status` column
UPDATE worldlifexpectancy t1 
JOIN worldlifexpectancy t2 
ON t1.Country = t2.Country 
SET t1.Status = 'Developing'
WHERE t1.Status = '' AND t2.Status = 'Developing';

UPDATE worldlifexpectancy t1 
JOIN worldlifexpectancy t2 
ON t1.Country = t2.Country 
SET t1.Status = 'Developed'
WHERE t1.Status = '' AND t2.Status = 'Developed';

-- Fill missing life expectancy values with average of adjacent years
UPDATE worldlifexpectancy t1
JOIN worldlifexpectancy t2 
ON t1.Country = t2.Country 
AND t1.Year = t2.Year - 1 
JOIN worldlifexpectancy t3
ON t1.Country = t3.Country 
AND t1.Year = t3.Year + 1 
SET t1.Lifeexpectancy = ROUND((t2.Lifeexpectancy + t3.Lifeexpectancy) / 2, 1)
WHERE t1.Lifeexpectancy = '';

-- **Section 3: Analysis and Insights**
-- Ranking countries based on a composite score
SELECT 
    Country,
    ROUND(AVG(Lifeexpectancy),1) AS AvgLifeExpectancy,
    ROUND(AVG(GDP),1) AS AvgGDP,
    ROUND(AVG(Schooling),1) AS AvgSchooling,
    ROUND(AVG((Polio + Diphtheria) / 2),1) AS AvgImmunizationRate,
    ROUND((AVG(Lifeexpectancy) * 0.4 + AVG(GDP) * 0.3 + AVG(Schooling) * 0.2 + AVG((Polio + Diphtheria) / 2) * 0.1),1) AS CompositeScore
FROM worldlifexpectancy
GROUP BY Country
ORDER BY CompositeScore DESC;

-- Global trends in life expectancy
SELECT 
    Year,
    ROUND(AVG(Lifeexpectancy),1) AS GlobalAvgLifeExpectancy
FROM worldlifexpectancy
GROUP BY Year
ORDER BY Year;

-- Top 10 years and countries by life expectancy
SELECT 
    Year,
    Country,
    ROUND(AVG(Lifeexpectancy),1) AS AvgLifeExpectancy
FROM worldlifexpectancy
GROUP BY Year, Country
ORDER BY Year, AvgLifeExpectancy DESC
LIMIT 10;

-- Relationship between health expenditure and life expectancy
SELECT 
    Country,
    AVG(percentageexpenditure) AS AvgHealthExpenditure,
    AVG(Lifeexpectancy) AS AvgLifeExpectancy
FROM worldlifexpectancy
GROUP BY Country
ORDER BY AvgHealthExpenditure DESC;

-- Countries with the largest improvement in life expectancy
SELECT 
    Country,
    MAX(Lifeexpectancy) - MIN(Lifeexpectancy) AS LifeExpectancyChange
FROM worldlifexpectancy
GROUP BY Country
ORDER BY LifeExpectancyChange DESC;

-- Countries with declining life expectancy
SELECT 
    Country,
    MAX(Lifeexpectancy) - MIN(Lifeexpectancy) AS LifeExpectancyChange
FROM worldlifexpectancy
GROUP BY Country
HAVING LifeExpectancyChange < 0;

--Calculate the average year-over-year growth in life expectancy
SELECT 
    Year,
    ROUND(AVG(Lifeexpectancy) - LAG(ROUND(AVG(Lifeexpectancy), 2)) OVER (ORDER BY Year), 2) AS AvgGrowth
FROM worldlifexpectancy
GROUP BY Year
ORDER BY Year;

-- Calculate the overall average year-over-year growth in life expectancy
WITH YearlyGrowth AS (
    SELECT 
        Year,
        ROUND(AVG(Lifeexpectancy) - LAG(AVG(Lifeexpectancy)) OVER (ORDER BY Year), 2) AS YearlyGrowth
    FROM worldlifexpectancy
    GROUP BY Year
)
SELECT 
    CONCAT(ROUND(AVG(YearlyGrowth), 2) * 100, '%') AS OverallAvgGrowth
FROM YearlyGrowth
WHERE YearlyGrowth IS NOT NULL;
