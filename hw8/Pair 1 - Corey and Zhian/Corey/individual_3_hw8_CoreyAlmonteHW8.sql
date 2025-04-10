USE AdventureWorks2017;
GO

-- 1. Running total of each customer's orders. Including discounts and tax. 
SELECT 
	ROW_NUMBER() 
        OVER (
            PARTITION BY SOH.CustomerID
            ORDER BY SOH.OrderDate
        ) AS row_num,
	SOH.CustomerID, CAST(SOH.OrderDate AS DATE) AS OrderDate,
	SUM(SOD.OrderQty*SOD.UnitPrice*(1-SOD.UnitPriceDiscount)+SOH.TaxAmt) OVER(
		PARTITION BY SOH.CustomerID
		ORDER BY SOH.OrderDate
		ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS runvalFROM Sales.SalesOrderDetail AS SOD	INNER JOIN Sales.SalesOrderHeader SOH		ON SOD.SalesOrderID = SOH.SalesOrderID;-- 2. Returns the 90th percentile of the top unique products ordering customers. Willing to try new products.--ntile kept returning 1. do not know why. WITH UniqueProductsPerOrder AS (
    SELECT 
        SOH.CustomerID,
        SOD.SalesOrderID,
        COUNT(DISTINCT SOD.ProductID) AS UniqueProductCount
    FROM Sales.SalesOrderDetail AS SOD
    INNER JOIN Sales.SalesOrderHeader AS SOH 
        ON SOD.SalesOrderID = SOH.SalesOrderID
    GROUP BY SOH.CustomerID, SOD.SalesOrderID
),
MaxUniqueProductsPerCustomer AS (
    SELECT 
        CustomerID,
        MAX(UniqueProductCount) AS MaxUniqueProductsInOrder
    FROM UniqueProductsPerOrder
    GROUP BY CustomerID
),
RankedCustomers AS (
SELECT 
    CustomerID,
    MaxUniqueProductsInOrder,
    PERCENT_RANK() OVER (ORDER BY MaxUniqueProductsInOrder) AS percent_rank
FROM MaxUniqueProductsPerCustomer
)
SELECT *
FROM RankedCustomers
WHERE percent_rank >= .9
ORDER BY MaxUniqueProductsInOrder DESC;

--  3. Returns whether a customer bought products 707-710 for a particular order
WITH ProductCounts AS (
    SELECT 
        SOH.CustomerID,
        SOD.SalesOrderID,
        SOD.ProductID
    FROM Sales.SalesOrderDetail AS SOD
    INNER JOIN Sales.SalesOrderHeader AS SOH 
        ON SOD.SalesOrderID = SOH.SalesOrderID
)
SELECT *
FROM (
    SELECT 
        CustomerID,
        SalesOrderID,
        ProductID
    FROM ProductCounts
) AS SourceTable
PIVOT (
    COUNT(ProductID) 
    FOR ProductID IN ([707], [708], [709], [710]) 
) AS PivotTable;

-- 4. Return all employees of the month for. The employee of the month has the most orders that month.
SELECT 
	SalesPersonID,
    OrderYear, 
    OrderMonth,  
    NumOrders
FROM (
    SELECT 
        ROW_NUMBER() OVER (
            PARTITION BY YEAR(SOH.OrderDate), MONTH(SOH.OrderDate) 
            ORDER BY COUNT(SOH.SalesPersonID) DESC
        ) AS SalesRank,

        SalesPersonID,
        YEAR(SOH.OrderDate) AS OrderYear,
        DATENAME(MONTH, SOH.OrderDate) AS OrderMonth,
        COUNT(SOH.SalesPersonID) AS NumOrders

    FROM Sales.SalesOrderHeader AS SOH
		INNER JOIN HumanResources.Employee AS E
			ON E.BusinessEntityID = SOH.SalesPersonID
    GROUP BY 
        YEAR(SOH.OrderDate), 
        MONTH(SOH.OrderDate), 
        DATENAME(MONTH, SOH.OrderDate),
		SalesPersonID
) AS RankedSales
WHERE SalesRank = 1
ORDER BY OrderYear;

--5. Return a ranking by job title of the most sick leavve to the least
SELECT 
    BusinessEntityID,
    JobTitle,
    VacationHours,
    SickLeaveHours,
    RANK() OVER (PARTITION BY JobTitle ORDER BY VacationHours DESC) AS VacationRank,
    
    CASE 
        WHEN SickLeaveHours >= 60 THEN 'A lot of Sick Leave'
        WHEN SickLeaveHours BETWEEN 30 AND 59 THEN 'Some Sick Leave'
        ELSE 'A little bit of Sick Leave'
    END AS SickLeaveCategory

FROM HumanResources.Employee
ORDER BY JobTitle, VacationRank;


--6.  Count job titles based on gender. Some data analysis
SELECT *
FROM (
    SELECT 
        JobTitle,
        Gender
    FROM HumanResources.Employee
) AS SourceTable
PIVOT (
    COUNT(Gender)
    FOR Gender IN ([M], [F])
) AS PivotTable
ORDER BY JobTitle;

--7. Top 99th percentile for most male and female dominated jobs
WITH PivotedGenderCounts AS (
    SELECT *
    FROM (
        SELECT 
            JobTitle,
            Gender
        FROM HumanResources.Employee
    ) AS SourceTable
    PIVOT (
        COUNT(Gender)
        FOR Gender IN ([M], [F])
    ) AS PivotTable
),
RankedGenderCounts AS (
    SELECT *,
        PERCENT_RANK() OVER (ORDER BY [M]) AS MalePercentile,
        PERCENT_RANK() OVER (ORDER BY [F]) AS FemalePercentile
    FROM PivotedGenderCounts
)
SELECT *
FROM RankedGenderCounts
WHERE MalePercentile >= 0.99 OR FemalePercentile >= 0.99
ORDER BY JobTitle;

--8 Pivot table for counting 0 for hourly and 1 for salaried
SELECT *
FROM (
    SELECT 
        JobTitle,
        SalariedFlag
    FROM HumanResources.Employee
) AS SourceTable
PIVOT (
    COUNT(SalariedFlag)
    FOR SalariedFlag IN ([0], [1])
) AS PivotTable
ORDER BY JobTitle;


-- 9. Track prices changes.
WITH TrackProductID AS (
    SELECT 
        SOD.ProductID, 
        SOD.UnitPrice, 
        CAST(SOD.ModifiedDate AS DATE) AS ModifiedDate
    FROM Sales.SalesOrderDetail AS SOD
    WHERE SOD.ProductID = 726
),
WithLag AS (
    SELECT *,
        LAG(UnitPrice) OVER (ORDER BY ModifiedDate) AS PrevPrice
    FROM TrackProductID
),
ChangeGroups AS (
    SELECT *,
        SUM(CASE WHEN UnitPrice <> PrevPrice OR PrevPrice IS NULL THEN 1 ELSE 0 END)
            OVER (ORDER BY ModifiedDate ROWS UNBOUNDED PRECEDING) AS PriceGroup
    FROM WithLag
),
PricePeriods AS (
    SELECT 
        ProductID,
        UnitPrice AS Price,
        MIN(ModifiedDate) AS StartDate,
        MAX(ModifiedDate) AS EndDate
    FROM ChangeGroups
    GROUP BY ProductID, UnitPrice, PriceGroup
)

SELECT *
FROM PricePeriods
ORDER BY StartDate;

-- 10. How many times was the 726 product id sold at each aprticular unit price
SELECT *
FROM (
    SELECT 
        SOD.ProductID,
        SOD.UnitPrice
    FROM Sales.SalesOrderDetail AS SOD
	WHERE SOD.ProductID=726
) AS SourceTable
PIVOT (
    COUNT(UnitPrice)
    FOR UnitPrice IN ([183.93820], [202.332], [249.5428])
) AS PivotTable
ORDER BY ProductID;



