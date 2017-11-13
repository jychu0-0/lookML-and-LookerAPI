PART I:

Your task is the following:

1. Provide a set of recommendations on how to improve our business or product based on the attached dataset. This is intended to be fairly open-ended - there's no right or wrong answer! We're more concerned with your approach and the insights you uncover.


When thinking about potential improvement to the business, I looked to another industry that shares the same components/concepts and started with challenges they face. Transportation networking (i.e. Uber and Lyft) seemed like obvious choice. One challenge that I thought to be directly relevant is the ongoing battle to win and maintain drivers. 

In order to keep to ensure that the supply of drivers is adequate enough to keep with customer demand, both companies need to keep their drivers happy. They do this by incentivizing drivers with bonuses for # of completed rides. However, with the increase in the supply of drivers needs to be in line with the demand for rides to, again, keep drivers happy. If there are more drivers than there are requested rides, you have a lot of drivers sitting around unhappy.

So I my recommendations are the same. First, incentivize Dashers to not only do more deliveries but deliver them quickly. Second, stimulate customers to place more delivery orders.

Incentivizing Dashers
I started by distilling the "Customer placed order datetime" and "Delivered to consumer datetime" fields into a single time from ordering to delivery in minutes on the source tab of the attached sheet. In the "PV Avg Time to Delivery" tab I started to compare the average time to delivery of each Driver ID for each Restaurant ID to the different regions. You could essentially incentivize Dashers by doing an additional calculation based on # of delivery's that were faster than the Restaurant to Region average by a certain amount and pay them a bonuses accordingly. Happy Dashers!

I realize using "Driver at restaurant datetime" - "Delivered to consumer datetime" would have been a better metric but there were too many blank fields (another improvement to business would be to minimize missing data!) and leaving an x factor how long before an order is placed to being sent to a restaurant could help govern how much bonuses are being paid out. 

Stimulate Customer Orders
Now we want more customers to order, but really we prefer the better customers to order more. So what makes a good customer? In my mind, a good customer keeps your Dashers happy so ones that order frequently and tip well. In the PV Tip-Refund tab I compared the average % tip with the overall % of cumulative order totals tipped for each customer and found that these were generally the same, suggesting that a customer's tipping behavior is relatively consistent. So I took the average % tipped less the average % refunded (net % tip) as the metric I wanted to use.

I simply multiplied my two signals for a good customer (net % tip and # of orders) to give each customer a score. Using these customer scores we could provide "better" customers incentives like discount vouchers or even have a frequent flyer type membership wherein customers with lots of order and high tipping get some small fraction of a % discount to all orders over some threshold. This keeps customers wanting to order via DoorDash and Dashers wanting to service DoorDash than one of its competitors. Happy Dashers AND Happy Customers!

Doing this exercise I notices a couple of lines that were throwing up errors in my calc. This was where customers had some refund amount but no total $ ordered. Perhaps there should be some measure in place where a customer is refunded at max what $ they actually paid.


2. Choose one of the recommendations/insights you uncovered (in #1) and outline an experiment you would like to run to test your suggested product/business recommendation. Please state your hypothesis, describe how you would structure your experiment, list your success metrics and describe the implementation.


It seems like there might be a lot of exogenous factors that could influence how quickly Dashers deliver food, so let's go with Stimulating Customer Orders. Customer ordering behavior should be much easier to track and consistent, right?

My hypothesis is that you can incentivize customers to place more orders through DoorDash than they already do. The frequent flyer type program would be more difficult to implement and get going so we'll go with a simple discount voucher that could be sent out. 

Experiment
1. Sample: Pick a region where there is a large population of customers who a) order regularly and b) have been doing so for a long time. This could be determined by looking at total order count and the first datetime they placed an order. Split these customers into cohorts based on average order total. Larger averages could indicate customer is ordering for spouse or family and may be more or less easily manipulated to order more.

2. Experiment: Separate these cohorts into a control (does not receive any discounts) and the experimental group (receives some discount for a short period of time). I'd like to use a discount % of the order total, as it would further provide insight/data on how to develop a frequent flyer program, but this could be problematic if exploited. People could begin placing a super large order for more people then themselves and the cost of such a discount would increase and the data becomes less useful. We could impose the lesser of % or $ amounts on the discount.

3. Metric: Monitor the changes in  average number of orders and average order totals. This will tell you whether the discounts will encourage customers. We'd want to see an increase in the average number of orders and the average order total. Restaurant, Customer and Dashers Happy!

4. Repeat: There might be some exogenous factors that cause increased ordering # and $ like weather or road construction causing traffic. Repeat this process in different areas and at different times in the year.

3. Let's assume that the experiment you ran (in #2) proved your hypothesis was true. How would you suggest implementing the change on a larger scale? What are some operational challenges you might encounter and how would you mitigate their risk?

Every market is different just. The discounts might not, in fact, increase ordering behavior of customers in some areas and you end us just taking a hit to revenue. Alternatively, a market may be extremely responsive to discounts and the increase in orders might exceed the capacity of Dashers and result in Customers waiting longer for food and ultimately hurting their experience.

With any new initiative, a limited soft launch is ideal - especially in the larger, riskier markets (mo people, mo money, mo problems). You could mitigate this by rolling out discounts based on their customer score. Either start with the highest scores and incrementally roll it out to lower thresholds or implement a tiered discount structure.
Column Names:

Customer placed order datetime: Time that customer placed the order; the format is <day> <hour>:<minute>:<second>
Placed order with restaurant datetime: Time that restaurant received order; the format is <day> <hour>:<minute>:<second>
Driver at restaurant datetime: Time that driver arrives at restaurant; the format is <day> <hour>:<minute>:<second>
Delivered to consumer datetime: Time that driver delivered to customer; the format is <day> <hour>:<minute>:<second>
Driver ID: Unique identifier of driver
Restaurant ID: Unique identifier of restaurant
Consumer ID: Unique identifier of customer
Is New: Equals TRUE for a consumer's first delivery; FALSE if a consumer has placed a prior order.
Delivery Region: City where restaurant is located
Is ASAP: Equals TRUE for on-demand orders; FALSE for scheduled deliveries (e.g., a customer places an order at 10am for 1pm delivery)
Order total: Amount customer spent (including delivery fee); units are in dollars
Amount discount: Amount of discounts redeemed (e.g., for referrals); units are in dollars
Amount of tip: Amount of tip given; units are in dollars
Refunded amount: Amount refunded to customer; units are in dollars
Times: Time is in UTC and we operate on PDT (daylight savings)

CHU FEEDBACK - Having these column names here is a bit confusing. I started the SQL exercise using these columns as if they were in a table then realize later that the Tables I was supposed to use were in that schema file.
PART II:

4. Directions: We recommend you sketch out your logic in words in addition to the writing the SQL. If you can not complete the exercise in a single query, get as far as you can with querying and then explain how you would complete the question in the most programmatic way (in other words, in the fewest number of queries and/or other analytical steps). 

a. Write a query to calculate the average earnings per hour by day of week.
FYI - I work primarily in postgreSQL. I realize an order from creation to delivery can span multiple days, so I'll use dash_end_time for the day of the week.


To derive the average I'll use the sum of Order total and divide that by the difference between Driver at restaurant datetime and Delivered to consumer datetime. When for precision I have a habit of doing time differences by converting to epoch then converting back to the desired unit of time measure. It might seem superfluous, but it makes it easier to convert make a change into per day, per min, per second by just changing a constant.

I'm assuming that only total_pay might be NULL if a Dasher doesn't get paid at all.

SELECT 
day_of_week
, overall_total_pay / overall_hours_works AS average_earning_per_hour
FROM(SELECT 
CASE WHEN EXTRACT(DOW FROM dash_end_time) = 0 THEN 'Sunday'
           WHEN EXTRACT(DOW FROM dash_end_time) = 1 THEN 'Monday'
           WHEN EXTRACT(DOW FROM dash_end_time) = 2 THEN 'Tuesday'
           WHEN EXTRACT(DOW FROM dash_end_time) = 3 THEN 'Wednesday'
           WHEN EXTRACT(DOW FROM dash_end_time) = 4 THEN 'Thursday'
           WHEN EXTRACT(DOW FROM dash_end_time) = 5 THEN 'Friday'
           WHEN EXTRACT(DOW FROM dash_end_time) = 6 THEN 'Saturday'  ELSE NULL END AS day_of_week
, SUM(EXTRACT(EPOCH FROM dash_end_time - dash_start_time) / 3600) AS overall_hours_worked
, SUM(coalesce(total_pay,0)) AS overall_total_pay
FROM source.Dash
GROUP BY 1)


b. Please write a query to calculate the average earnings per hour during lunch (11am-2pm) in submarket_id 3.
Here I'm assuming that every Dash has a dasher_id and that every dasher_id exists in Dasher so I can INNER JOIN.


Again, I'll use the dash_end_time to filter between 11am to 2pm.

SELECT 
day_of_week
, overall_total_pay / overall_hours_works AS average_earning_per_hour
FROM(SELECT 
CASE WHEN EXTRACT(DOW FROM dash_end_time) = 0 THEN 'Sunday'
           WHEN EXTRACT(DOW FROM dash_end_time) = 1 THEN 'Monday'
           WHEN EXTRACT(DOW FROM dash_end_time) = 2 THEN 'Tuesday'
           WHEN EXTRACT(DOW FROM dash_end_time) = 3 THEN 'Wednesday'
           WHEN EXTRACT(DOW FROM dash_end_time) = 4 THEN 'Thursday'
           WHEN EXTRACT(DOW FROM dash_end_time) = 5 THEN 'Friday'
           WHEN EXTRACT(DOW FROM dash_end_time) = 6 THEN 'Saturday'  ELSE NULL END AS day_of_week
, SUM(EXTRACT(EPOCH FROM dash_end_time - dash_start_time) / 3600) AS overall_hours_worked
, SUM(coalesce(total_pay,0)) AS overall_total_pay
FROM source.Dash AS dash
INNER JOIN source.Dasher AS dasher ON dash.dasher_id = dasher.id
WHERE submarket_id = 3 
AND EXTRACT(HOUR FROM dash_end_time) >= "11"
AND EXTRACT(HOUR FROM dash_end_time) < "15"
GROUP BY 1)


c. Let’s say we want to target dashers who are in the bottom 50th percentile of total pay per hour in the last 30 days with a promotion. Please write a query to identify who these dashers are along with their email address. 
Again, I'm using the dash_end_time to calc the last 30 days of work. I haven't had a lot of exposure to filtering for a certain percentile. Normally I'd check the output to see if my query was correct, but I don't have that luxury here.


SELECT
email_address
, percentile_rank
FROM(SELECT
email_address
, percent_rank() OVER (ORDER BY average_earning_per_hour) AS percentile_rank
FROM(SELECT 
email_address
, overall_total_pay / overall_hours_works AS average_earning_per_hour
FROM(SELECT
email_address
, SUM(EXTRACT(EPOCH FROM dash_end_time - dash_start_time) / 3600) AS overall_hours_worked
, SUM(coalesce(total_pay,0)) AS overall_total_pay
FROM source.Dash AS dash
INNER JOIN source.Dasher AS dasher ON dash.dasher_id = dasher.id
WHERE DATE_PART('day', current_date::date - dash_end_time::date) <= 30
GROUP BY 1)))
WHERE percentile_rank <= .5)
