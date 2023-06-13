-- ### App Trader

-- Your team has been hired by a new company called App Trader to help them explore and gain insights from apps that are made available through the Apple App Store and Android Play Store. App Trader is a broker that purchases the rights to apps from developers in order to market the apps and offer in-app purchase. 

-- Unfortunately, the data for Apple App Store apps and Android Play Store Apps is located in separate tables with no referential integrity.

-- #### 1. Loading the data
-- a. Launch PgAdmin and create a new database called app_trader.  

-- b. Right-click on the app_trader database and choose `Restore...`  

-- c. Use the default values under the `Restore Options` tab. 

-- d. In the `Filename` section, browse to the backup file `app_store_backup.backup` in the data folder of this repository.  

-- e. Click `Restore` to load the database.  

-- f. Verify that you have two tables:  
--     - `app_store_apps` with 7197 rows  
--     - `play_store_apps` with 10840 rows
-- Combined 18037
-- 553 overlapping
-- Should be 17484 distinct

-- #### 2. Assumptions

-- Based on research completed prior to launching App Trader as a company, you can assume the following:

-- a. App Trader will purchase apps for 10,000 times the price of the app. For apps that are priced from free up to $1.00, the purchase price is $10,000.

	-- consider using bytes as a key!
	-- Found some duplicates -- including WWE

WITH price_cte AS (SELECT name, price
FROM app_store_apps
UNION ALL
SELECT name, price 
FROM (SELECT name,
	CASE WHEN price LIKE '$%' THEN CAST(SUBSTRING(price,2,length(price)) as float)
	ELSE CAST(price as float) END as price
	FROM play_store_apps) as sub)
	
	-- Now to identify all duplicates and find highest app price

SELECT p.name, a.name, p.price, a.price, GREATEST(p.price, a.price) as max_price
FROM (SELECT name,
	CASE WHEN price LIKE '$%' THEN CAST(SUBSTRING(price,2,length(price)) as float)
	ELSE CAST(price as float) END as price
	FROM play_store_apps) as p
FULL JOIN app_store_apps as a
ON a.name=p.name
ORDER BY max_price DESC;

	-- Added in coalesce to get rid of null values in names from app store exclusives 

SELECT COALESCE(p.name,a.name), GREATEST(p.price, a.price) as max_price,
	CASE WHEN GREATEST(p.price, a.price) > 1 THEN (10000 * GREATEST(p.price, a.price))
	ELSE 10000 END as cost
FROM (SELECT name,
	CASE WHEN price LIKE '$%' THEN CAST(SUBSTRING(price,2,length(price)) as float)
	ELSE CAST(price as float) END as price
	FROM play_store_apps) as p
FULL JOIN app_store_apps as a
ON a.name=p.name
ORDER BY max_price DESC; -- returns 17709 rows

	-- Use distinct unless you can clean it up upstream of this. what would happen if a dup name had different prices?

SELECT DISTINCT(COALESCE(p.name,a.name)), 
	GREATEST(p.price, a.price) as max_price,
	CASE WHEN GREATEST(p.price, a.price) > 1 THEN (10000 * GREATEST(p.price, a.price))
	ELSE 10000 END as cost
FROM (SELECT name,
	CASE WHEN price LIKE '$%' THEN CAST(SUBSTRING(price,2,length(price)) as float)
	ELSE CAST(price as float) END as price
	FROM play_store_apps) as p
FULL JOIN app_store_apps as a
	ON a.name=p.name
ORDER BY max_price DESC; --returns 16528 rows


	-- 18037 combined rows. 18037 minus 553 is 17484
	-- Are there any apps in app store but not play store? 6869
	-- In play store but not app store? 10287 (added equals 17156)
	-- There are 553 that overlap
	-- 17709 total entries. Why does this not equal the value up top? Difference is 225
	-- Should use FULL JOIN


-- - For example, an app that costs $2.00 will be purchased for $20,000.
    
-- - The cost of an app is not affected by how many app stores it is on. A $1.00 app on the Apple app store will cost the same as a $1.00 app on both stores. 
    
-- - If an app is on both stores, it's purchase price will be calculated based off of the highest app price between the two stores. 

-- b. Apps earn $5000 per month, per app store it is on, from in-app advertising and in-app purchases, regardless of the price of the app.

WITH stores AS (SELECT DISTINCT(name) as name
FROM app_store_apps
UNION ALL
SELECT DISTINCT(name)
FROM play_store_apps)

SELECT name, COUNT(name) * 5000 as monthly_earnings
FROM stores
GROUP BY name
ORDER BY monthly_earnings DESC -- returns 16526 rows

-- or --

SELECT COALESCE(p.name,a.name) as name, (COUNT(DISTINCT(p.name))+COUNT(DISTINCT(a.name))) * 5000 as monthly_earnings
FROM play_store_apps as p
FULL JOIN app_store_apps as a
ON a.name = p.name
GROUP BY p.name, a.name
ORDER BY monthly_earnings DESC; -- returns 16526 rows


-- - An app that costs $200,000 will make the same per month as an app that costs $1.00. 

-- - An app that is on both app stores will make $10,000 per month. 

-- c. App Trader will spend an average of $1000 per month to market an app regardless of the price of the app. If App Trader owns rights to the app in both stores, it can market the app for both stores for a single cost of $1000 per month.

SELECT DISTINCT(COALESCE(p.name,a.name)) as name, 1000 as monthly_cost
FROM play_store_apps as p
FULL JOIN app_store_apps as a
ON p.name = a.name

-- - An app that costs $200,000 and an app that costs $1.00 will both cost $1000 a month for marketing, regardless of the number of stores it is in.

-- d. For every half point that an app gains in rating, its projected lifespan increases by one year. In other words, an app with a rating of 0 can be expected to be in use for 1 year, an app with a rating of 1.0 can be expected to last 3 years, and an app with a rating of 4.0 can be expected to last 9 years.

SELECT DISTINCT(COALESCE(p.name,a.name)) as name,
	COALESCE(ROUND(ROUND((COALESCE(p.rating,a.rating) + COALESCE(a.rating,p.rating)),0)/2,1),0) as avg_rating,
	ROUND((1+COALESCE((2*ROUND(ROUND((COALESCE(p.rating,a.rating) + COALESCE(a.rating,p.rating)),0)/2,1)),0)),0) as lifespan
FROM play_store_apps as p
FULL JOIN app_store_apps as a
	ON a.name = p.name 
GROUP BY p.name, a.name, p.rating, a.rating;

	-- Keep in mind, still have to figure out how to avg the ratings for the duplicate names	
	
    
-- - App store ratings should be calculated by taking the average of the scores from both app stores and rounding to the nearest 0.5.

-- e. App Trader would prefer to work with apps that are available in both the App Store and the Play Store since they can market both for the same $1000 per month.

			  
SELECT DISTINCT(COALESCE(p.name,a.name))
FROM play_store_apps as p
INNER JOIN app_store_apps as a
USING (name)

-- #### 3. Deliverables

-- a. Develop some general recommendations as to the price range, genre, content rating, or anything else for apps that the company should target.

-- Minimize Purchase cost
-- Maximize Ratings
-- Preference for apps in both stores


-- Best genres (needs work)

WITH profit AS (SELECT DISTINCT(COALESCE(p.name,a.name)) as name,((((COUNT(DISTINCT(p.name))+COUNT(DISTINCT(a.name))) * 5000)-1000)*12*ROUND((1+COALESCE((2*ROUND(ROUND((COALESCE(p.rating,a.rating) + COALESCE(a.rating,p.rating)),0)/2,1)),0)),0)) - (CASE WHEN GREATEST(p.price, a.price) > 1 
			THEN ROUND((10000 * GREATEST(p.price, a.price,0)))
			ELSE 10000 END) as net_profit, GREATEST(p.price, a.price) as price,
				LEFT(COALESCE(p.genres,a.primary_genre), POSITION(';' in COALESCE(p.genres,a.primary_genre)) -1) as genre, ROUND(AVG(COALESCE(ROUND(ROUND((COALESCE(p.rating,a.rating) + COALESCE(a.rating,p.rating)),0)/2,1),0)),1) as genre_rating
	FROM (SELECT name, rating, genres,
	CASE WHEN price LIKE '$%' THEN CAST(SUBSTRING(price,2,length(price)) as float)
	ELSE CAST(price as float) END as price
	FROM play_store_apps) as p
FULL JOIN app_store_apps as a
	ON a.name=p.name
GROUP BY DISTINCT(COALESCE(p.name,a.name)), p.price,a.price,p.rating, a.rating,genres,a.primary_genre)

SELECT genre, COUNT(*),
	 ROUND(AVG(net_profit::numeric),0) as avg_genre_profit
FROM profit as p
GROUP BY genre
ORDER BY AVG(net_profit) DESC
LIMIT 25;
 

--Best Price Range (try to figure out how to do with a window function too)
--Advised to target apps under $10
		
WITH profit AS (SELECT DISTINCT(COALESCE(p.name,a.name)) as name,((((COUNT(DISTINCT(p.name))+COUNT(DISTINCT(a.name))) * 5000)-1000)*12*ROUND((1+COALESCE((2*ROUND(ROUND((COALESCE(p.rating,a.rating) + COALESCE(a.rating,p.rating)),0)/2,1)),0)),0)) - (CASE WHEN GREATEST(p.price, a.price) > 1 
			THEN ROUND((10000 * GREATEST(p.price, a.price,0)))
			ELSE 10000 END) as net_profit, GREATEST(p.price, a.price) as price
			 FROM (SELECT name, rating,
	CASE WHEN price LIKE '$%' THEN CAST(SUBSTRING(price,2,length(price)) as float)
	ELSE CAST(price as float) END as price
	FROM play_store_apps) as p
FULL JOIN app_store_apps as a
	ON a.name=p.name
GROUP BY DISTINCT(COALESCE(p.name,a.name)), p.price,a.price,p.rating, a.rating)
	
SELECT CASE WHEN price = 0 THEN 'Free'
			WHEN price <1 THEN 'Under $1'
			WHEN price <2 THEN '$1 - $2'
			WHEN price <3 THEN '$2 - $3'
			WHEN price <4 THEN '$3 - $4'
			WHEN price <5 THEN '$4 - $5'
			WHEN price <10 THEN '$5 - $10'
			WHEN price <20 THEN '$10 - $20'
			WHEN price <50 THEN '$20 - $50'
			WHEN price <100 THEN '$50 - $100'
			WHEN price <200 THEN '$100 - $200'
			ELSE 'Over $200' END as price_range, 
		COUNT(*) as price_count, ROUND(AVG(net_profit)::numeric,0) as avg_profit
FROM profit
GROUP BY price_range
ORDER BY avg_profit DESC;


-- b. Develop a Top 10 List of the apps that App Trader should buy.

SELECT DISTINCT(COALESCE(p.name,a.name)) as app_name, 
	CASE WHEN GREATEST(p.price, a.price) > 1 THEN ROUND((10000 * GREATEST(p.price, a.price,0)))
	ELSE 10000 END as purchase_price,
	(COUNT(DISTINCT(p.name))+COUNT(DISTINCT(a.name))) * 5000 as monthly_earnings, 
	1000 as marketing_cost,
	ROUND((1+COALESCE((2*ROUND(ROUND((COALESCE(p.rating,a.rating) + COALESCE(a.rating,p.rating)),0)/2,1)),0)),0) as lifespan,
	((((COUNT(DISTINCT(p.name))+COUNT(DISTINCT(a.name))) * 5000)-1000)*12*ROUND((1+COALESCE((2*ROUND(ROUND((COALESCE(p.rating,a.rating) + 		COALESCE(a.rating,p.rating)),0)/2,1)),0)),0)) - (CASE WHEN GREATEST(p.price, a.price) > 1 
													THEN ROUND((10000 * GREATEST(p.price, a.price,0)))
													ELSE 10000 END) as net_profit
FROM (SELECT name, rating,
	CASE WHEN price LIKE '$%' THEN CAST(SUBSTRING(price,2,length(price)) as float)
	ELSE CAST(price as float) END as price
	FROM play_store_apps) as p
FULL JOIN app_store_apps as a
	ON a.name=p.name
GROUP BY DISTINCT(COALESCE(p.name,a.name)), p.price,a.price,p.rating, a.rating
ORDER BY net_profit DESC; -- full table

-- consider reorganizing as cte 

SELECT DISTINCT(COALESCE(p.name,a.name)) as app_name, 
	((((COUNT(DISTINCT(p.name))+COUNT(DISTINCT(a.name))) * 5000)-1000)*12*ROUND((1+COALESCE((2*ROUND(ROUND((COALESCE(p.rating,a.rating) + 				COALESCE(a.rating,p.rating)),0)/2,1)),0)),0)) - (CASE WHEN GREATEST(p.price, a.price) > 1 
			THEN ROUND((10000 * GREATEST(p.price, a.price,0)))
			ELSE 10000 END) as net_profit
FROM (SELECT name, rating,
	CASE WHEN price LIKE '$%' THEN CAST(SUBSTRING(price,2,length(price)) as float)
	ELSE CAST(price as float) END as price
	FROM play_store_apps) as p
FULL JOIN app_store_apps as a
	ON a.name=p.name
WHERE COALESCE(p.name,a.name) IN 
	(SELECT DISTINCT(COALESCE(p.name,a.name))
	FROM play_store_apps as p
	INNER JOIN app_store_apps as a
	USING (name))
GROUP BY DISTINCT(COALESCE(p.name,a.name)), p.price,a.price,p.rating, a.rating
ORDER BY net_profit DESC; -- profit only

-- updated 2/18/2023
