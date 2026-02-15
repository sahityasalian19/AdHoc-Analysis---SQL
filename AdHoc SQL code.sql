-- 1) Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region
SELECT DISTINCT market 
FROM dim_customer
WHERE customer = 'Atliq Exclusive'
AND region = 'APAC';

/* 2) What is the percentage of unique product increase in 2021 vs. 2020? The final output contains these fields,
  unique_products_2020
  unique_products_2021
  percentage_chg*/
  
WITH product_counts AS (SELECT fiscal_year, COUNT(DISTINCT product_code) AS unique_products FROM fact_sales_monthly
WHERE fiscal_year IN ('2020','2021')
GROUP BY fiscal_year)

SELECT MAX(CASE WHEN fiscal_year = 2020 THEN unique_products END) AS unique_products_2020,
MAX(CASE WHEN fiscal_year = 2021 THEN unique_products END) AS unique_products_2021,
ROUND(
(
(MAX(CASE WHEN fiscal_year = 2021 THEN unique_products END) - MAX(CASE WHEN fiscal_year = 2020 THEN unique_products END))*100)/
MAX(CASE WHEN fiscal_year = 2020 THEN unique_products END),2) AS percentage_chg
FROM product_counts;

/* 3) Provide a report with all the unique product counts for each segment and sort them in descending order of product counts. 
The final output contains 2 fields,
segment
product_count*/

SELECT segment, COUNT(DISTINCT product_code) AS product_count 
FROM dim_product
GROUP BY segment
ORDER BY product_COUNT desc;

/* 4) Follow-up: Which segment had the most increase in unique products in 2021 vs 2020? The final output contains these fields, 
segment
product_count_2020
product_count_2021
difference */

WITH product_counts AS (SELECT p.segment, COUNT(DISTINCT s.product_code) AS product_count, s.fiscal_year FROM fact_sales_monthly s
JOIN dim_product p
ON s.product_code = p.product_code
WHERE fiscal_year IN ('2020','2021')
GROUP BY p.segment, s.fiscal_year
ORDER BY fiscal_year),
pivot_data AS(
SELECT segment, SUM(CASE WHEN fiscal_year = 2020 THEN product_count ELSE 0 END) AS product_count_2020,
SUM(CASE WHEN fiscal_year = 2021 THEN product_count ELSE 0 END) AS product_COUNT_2021
FROM product_counts
GROUP BY segment)
SELECT
    segment,
    product_count_2020,
    product_count_2021,
    (product_count_2021 - product_count_2020) AS difference
FROM pivot_data
ORDER BY difference DESC;

/* 5) Get the products that have the highest and lowest manufacturing costs. The final output should contain these fields,
product_code
product
manufacturing_cost*/

-- Solution a)
(SELECT m.product_code, p.product, m.manufacturing_cost 
FROM fact_manufacturing_cost m
JOIN dim_product p
ON m.product_code = p.product_code
ORDER BY m.manufacturing_cost
limit 1)
UNION
(SELECT m.product_code, p.product, m.manufacturing_cost FROM fact_manufacturing_cost m
JOIN dim_product p
ON m.product_code=p.product_code
ORDER BY m.manufacturing_cost desc
limit 1);

-- Solution b)
SELECT m.product_code, p.product, m.manufacturing_cost 
FROM fact_manufacturing_cost m
JOIN dim_product p
ON m.product_code=p.product_code
WHERE  m.manufacturing_cost = (SELECT MAX(manufacturing_cost) FROM fact_manufacturing_cost) or
m.manufacturing_cost = (SELECT Min(manufacturing_cost) FROM fact_manufacturing_cost)
ORDER BY m.manufacturing_cost desc;

/*6) Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the fiscal year 2021 
 and in the Indian market. The final output contains these fields,
customer_code
customer
average_discount_percentage */

SELECT c.customer_code, c.customer, ROUND(avg(pre_invoice_discount_pct),4) AS average_discount_percentage 
FROM fact_pre_invoice_deductions p
JOIN dim_customer c
ON p.customer_code = c.customer_code
WHERE p.fiscal_year = 2021
AND c.market = 'India'
GROUP BY p.customer_code
ORDER BY average_discount_percentage desc
Limit 5;

/* 7) Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month. This analysis helps to get an
idea of low and high-performing months and take strategic decisions. The final report contains these columns:
Month
Year
Gross sales Amount*/

SELECT CONCAT(MONTHNAME(s.date), ' (', YEAR(s.date), ')') AS 'Month', s.fiscal_year,
 ROUND(Sum((p.gross_price*s.sold_quantity)),2) AS Gross_sales_amount 
FROM fact_sales_monthly s
JOIN fact_gross_price p
ON s.product_code = p.product_code
WHERE s.customer_code in (SELECT customer_code FROM dim_customer WHERE customer = 'Atliq Exclusive')
GROUP BY CONCAT(MONTHNAME(s.date), ' (', YEAR(s.date), ')'), s.fiscal_year
ORDER BY 
  s.fiscal_year,
  CASE 
    WHEN MONTH(s.date) >= 9 THEN MONTH(s.date) - 8
    ELSE MONTH(s.date) + 4
  END; 

/*8) In which quarter of 2020, got the Maximum total_sold_quantity? The final output contains these fields sorted by the total_sold_quantity,
Quarter
total_sold_quantity*/

SELECT CONCAT("Q", CEILING((MONTH(DATE_ADD(date, INTERVAL 4 MONTH))/3))) AS quarter, 
sum(sold_quantity) AS total_sold_quantity 
FROM fact_sales_mONthly s
WHERE fiscal_year = 2020
GROUP BY CONCAT("Q", CEILING((MONth(DATE_ADD(date, INTERVAL 4 MONTH))/3)))
ORDER BY total_sold_quantity desc;

/* 9) Which channel helped to bring more gross sales in the fiscal year 2021 AND the percentage of contribution? The final output contains these fields,
channel
gross_sales_mln
percentage*/

with cte as
(
select
    c.channel,
    round(sum(s.sold_quantity*g.gross_price)/1000000,2) as gross_sales_mln
from dim_customer as c
join fact_sales_monthly as s
on c.customer_code=s.customer_code
join fact_gross_price as g
on g.product_code=s.product_code 
and g.fiscal_year=s.fiscal_year
where s.fiscal_year=2021
group by channel
order by gross_sales_mln desc
)
select *, CONCAT(round(gross_sales_mln*100/sum(gross_sales_mln) over(),2),"%")as percentage
from cte;

/* 10. Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? The final output contains these fields,
division
product_code
product
total_sold_quantity
rank_order*/ 

WITH cte1 AS(SELECT p.division, s.product_code, p.product, p.variant, sum(sold_quantity) AS total_sold_quantity
FROM fact_sales_monthly s
JOIN dim_product p
ON s.product_code = p.product_code
WHERE s.fiscal_year = 2021
GROUP BY product_code
ORDER BY product_code),
cte2 AS (SELECT division, product_code, Concat(product, ' (', variant, ')') as product, total_sold_quantity, dense_rank() over(partition by division ORDER BY total_sold_quantity desc) AS 
rank_order
FROM cte1)
SELECT * FROM cte2 WHERE rank_order <=3;






