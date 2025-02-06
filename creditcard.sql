use creditCard;

-- ALTER TABLE `order` 
-- RENAME TO  `orders`;


-- <--------------------views----------------------->
CREATE VIEW accounts AS
    (SELECT 
        account_id,
        district_id,
        frequency,
        STR_TO_DATE(date, '%y%m%d') AS Date
    FROM
        account);


CREATE VIEW cards AS
    (SELECT 
        card_id,
        disp_id,
        type,
        STR_TO_DATE(issued, '%y%m%d') AS date
    FROM
        card);


CREATE VIEW clients AS
    (SELECT 
        client_id,
        district_id,
        CASE
            WHEN
                SUBSTRING(birth_number, 3, 1) IN ('0' , '1')
            THEN
                STR_TO_DATE(CONCAT('19',
                                SUBSTRING(birth_number, 1, 2),
                                '-',
                                SUBSTRING(birth_number, 3, 2),
                                '-',
                                SUBSTRING(birth_number, 5, 2)),
                        '%Y-%m-%d')
            ELSE STR_TO_DATE(CONCAT('19',
                            SUBSTRING(birth_number, 1, 2),
                            '-',
                            SUBSTRING(birth_number, 3, 2) - 50,
                            '-',
                            SUBSTRING(birth_number, 5, 2)),
                    '%Y-%m-%d')
        END AS date,
        CASE
            WHEN SUBSTRING(birth_number, 3, 1) IN ('0' , '1') THEN 'M'
            ELSE 'F'
        END AS gender
    FROM
        client);


CREATE VIEW loans AS
    (SELECT 
        loan_id,
        account_id,
        amount,
        duration,
        payments,
        STR_TO_DATE(date, '%y%m%d') AS date
    FROM
        loan);



CREATE TEMPORARY TABLE CLIENT_INFO AS SELECT
    c.client_id,
    c.district_id,
    c.gender,
    COUNT(DISTINCT a.account_id) AS num_accounts,
    COUNT(DISTINCT l.loan_id) AS num_loans,
    CASE
    WHEN MAX(a.frequency) = "POPLATEK MESICNE" THEN "Monthly"
	WHEN MAX(a.frequency) = "POPLATEK TYDNE" THEN "Weekly"
	WHEN MAX(a.frequency) = "POPLATEK PO OBRATU" THEN "After Transaction"
    END AS Statement,
    COUNT(DISTINCT t.trans_id) AS num_transactions,
    COUNT(DISTINCT o.order_id) AS num_orders
FROM
    Clients c
LEFT JOIN
    disp d ON c.client_id = d.client_id
LEFT JOIN
    accounts a ON d.account_id = a.account_id
LEFT JOIN
    loans l ON a.account_id = l.account_id
LEFT JOIN
    trans t ON a.account_id = t.account_id
LEFT JOIN
    orders o ON a.account_id = o.account_id
GROUP BY
    c.client_id,c.district_id, c.gender
    ;

-- <---------------------------INSIGHTS-----------------------> 
-- 1. TOTAL CLIENTS 
SELECT 
    COUNT(client_id) AS Total_number_of_clients
FROM
    CLIENT_INFO;

-- 2. NUMBER OF FEMALE AND MALE CLIENTS 
SELECT 
    gender, COUNT(gender) AS Total
FROM
    CLIENT_INFO
GROUP BY gender
ORDER BY Total DESC;

-- 3. TOP 10 DISTRICT WITH HIGEST NUMBER OF ACCOUNTS

SELECT 
    d.A2 AS district_name,
    d.A3 AS region,
    COUNT(c.client_id) AS num_clients
FROM
    district d
        LEFT JOIN
    client c ON d.A1 = c.district_id
GROUP BY district_name , region
ORDER BY num_clients DESC
LIMIT 10;
    
-- 4.	Year in which the maximum number of accounts was created

SELECT 
    EXTRACT(YEAR FROM date) AS account_creation_year,
    COUNT(*) AS num_accounts
FROM
    accounts
GROUP BY account_creation_year
ORDER BY num_accounts DESC
LIMIT 1;

-- 5.	 Top 5 Loans with Highest Amounts and Corresponding Client_id.
SELECT 
    loan_id, C.client_id, L.account_id, amount, duration, L.status
FROM
    Loans L
        JOIN
    Disp D ON L.account_id = D.account_id
        JOIN
    Client C ON D.client_id = C.client_id
ORDER BY L.amount DESC
LIMIT 5;

-- 6.	Accounts with Both Loans and Orders

SELECT A.account_id
FROM Accounts A
WHERE EXISTS (
    SELECT 1 FROM Loans WHERE Loans.account_id = A.account_id
) AND EXISTS (
    SELECT 1 FROM Orders WHERE Orders.account_id = A.account_id
);

-- 7.	Top 5 Districts with the Highest Average Loan Amounts:

SELECT D.A2 AS district_name, AVG(L.amount) AS average_loan_amount
FROM District D
JOIN Clients C ON D.A1 = C.district_id
JOIN Disp DP ON C.client_id = DP.client_id
JOIN Loans L ON DP.account_id = L.account_id
GROUP BY D.A2
ORDER BY average_loan_amount DESC
LIMIT 5;

-- 8.	top 5 Credit card used more according to district corresponding useages count

SELECT
    District.A2 AS district_name,
    Card.type AS credit_card_type,
    COUNT(Disp.disp_id) AS usage_count
FROM
    Disp
JOIN
    Card ON Disp.disp_id = Card.disp_id
JOIN
    Client ON Disp.client_id = Client.client_id
JOIN
    District ON Client.district_id = District.A1
GROUP BY
    district_name, credit_card_type
ORDER BY
    usage_count DESC,district_name
    LIMIT 5;

-- 9.	Most prefered CREDIT card 
SELECT
    Cards.type AS credit_card_type,
    COUNT(Cards.type) AS Total_number
FROM
	CARDS
GROUP BY
    credit_card_type
ORDER BY
    Total_number DESC
LIMIT 1;

-- 10. Ranking Credit Cards by Usage Count Within Each REGION:
WITH CardUsage AS (
    SELECT 
        D.A3 AS Region,
        C.type AS credit_card_type,
        COUNT(Disp.disp_id) AS usage_count,
        ROW_NUMBER() OVER (PARTITION BY D.A3 ORDER BY COUNT(Disp.disp_id) DESC) AS rank_within_district
    FROM Disp 
    JOIN Card C ON Disp.disp_id = C.disp_id
    JOIN Client CL ON Disp.client_id = CL.client_id
    JOIN District D ON CL.district_id = D.A1
    GROUP BY D.A3, C.type
)
SELECT Region, credit_card_type, usage_count
FROM CardUsage
WHERE rank_within_district = 1 order by usage_count desc;

-- 11. Ranking Credit Cards by Usage Count Within Each District name:
WITH CardUsage AS (
    SELECT 
        D.A2 AS district_name,
        C.type AS credit_card_type,
        COUNT(Disp.disp_id) AS usage_count,
        ROW_NUMBER() OVER (PARTITION BY D.A2 ORDER BY COUNT(Disp.disp_id) DESC) AS rank_within_district
    FROM Disp 
    JOIN Card C ON Disp.disp_id = C.disp_id
    JOIN Client CL ON Disp.client_id = CL.client_id
    JOIN District D ON CL.district_id = D.A1
    GROUP BY D.A2, C.type
)
SELECT district_name, credit_card_type, usage_count
FROM CardUsage
WHERE rank_within_district = 1 order by usage_count desc;

-- 12.	Running Total of Credit Card Usage Across All Districts:

WITH CardUsage AS (
    SELECT 
        DT.A2 AS district_name,
        C.type AS credit_card_type,
        COUNT(D.disp_id) AS usage_count
    FROM Disp D
    JOIN Card C ON D.disp_id = C.disp_id
    JOIN Client CL ON D.client_id = CL.client_id
    JOIN District DT ON CL.district_id = DT.A1
    GROUP BY DT.A2, C.type
)
SELECT 
    district_name,
    credit_card_type,
    usage_count,
    SUM(usage_count) OVER (ORDER BY usage_count DESC, district_name) AS total_usage_across_districts
FROM CardUsage
ORDER BY usage_count DESC, district_name;



