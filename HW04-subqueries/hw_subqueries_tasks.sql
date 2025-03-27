
/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "03 - Подзапросы, CTE, временные таблицы".

Задания выполняются с использованием базы данных WideWorldImporters.

Бэкап БД можно скачать отсюда:
https://github.com/Microsoft/sql-server-samples/releases/tag/wide-world-importers-v1.0
Нужен WideWorldImporters-Full.bak

Описание WideWorldImporters от Microsoft:
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-what-is
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-oltp-database-catalog
*/

-- ---------------------------------------------------------------------------
-- Задание - написать выборки для получения указанных ниже данных.
-- Для всех заданий, где возможно, сделайте два варианта запросов:
--  1) через вложенный запрос
--  2) через WITH (для производных таблиц)
-- ---------------------------------------------------------------------------

USE WideWorldImporters

/*
1. Выберите сотрудников (Application.People), которые являются продажниками (IsSalesPerson), 
и не сделали ни одной продажи 04 июля 2015 года. 
Вывести ИД сотрудника и его полное имя. 
Продажи смотреть в таблице Sales.Invoices.
*/

select p.PersonID, p.FullName
from Application.People p
where p.IsSalesperson = 1
	and not exists 
	(select * from Sales.Invoices i where i.InvoiceDate = '2015-07-04' and i.SalespersonPersonID = p.PersonID)


;with PersonIDs as
	(select distinct SalespersonPersonID
	from Sales.Invoices
	where InvoiceDate = '2015-07-04')
select p.PersonID, p.FullName
from Application.People p
left join PersonIDs pi on p.PersonID = pi.SalespersonPersonID
where p.IsSalesperson = 1 and pi.SalespersonPersonID is null

/*
2. Выберите товары с минимальной ценой (подзапросом). Сделайте два варианта подзапроса. 
Вывести: ИД товара, наименование товара, цена.
*/

select StockItemID, StockItemName, UnitPrice
from Warehouse.StockItems
where UnitPrice = (select min(UnitPrice) from Warehouse.StockItems)


select StockItemID, StockItemName, UnitPrice
from Warehouse.StockItems
where UnitPrice <= all(select UnitPrice from Warehouse.StockItems)

/*
3. Выберите информацию по клиентам, которые перевели компании пять максимальных платежей 
из Sales.CustomerTransactions. 
Представьте несколько способов (в том числе с CTE). 
*/

select c.CustomerID, c.CustomerName
from Sales.Customers c
where c.CustomerID in
	(select top 5 CustomerID from Sales.CustomerTransactions order by TransactionAmount desc)

;with TopFiveCustomers as
	(select top 5 CustomerID from Sales.CustomerTransactions order by TransactionAmount desc)
select distinct c.CustomerID, c.CustomerName
from Sales.Customers c
join TopFiveCustomers tfc on c.CustomerID = tfc.CustomerID

/*
4. Выберите города (ид и название), в которые были доставлены товары, 
входящие в тройку самых дорогих товаров, а также имя сотрудника, 
который осуществлял упаковку заказов (PackedByPersonID).
*/

select c.CityID, c.CityName, p.FullName as PackedByPerson, il.StockItemID
from Application.Cities c
join Sales.Customers cr on cr.DeliveryCityID = c.CityID
join Sales.Invoices i on i.CustomerID = cr.CustomerID
join Sales.InvoiceLines il on i.InvoiceID = il.InvoiceID
join Application.People p on p.PersonID = i.PackedByPersonID
where il.StockItemID in (select top 3 with ties StockItemID from Warehouse.StockItems order by UnitPrice desc)

-- ---------------------------------------------------------------------------
-- Опциональное задание
-- ---------------------------------------------------------------------------
-- Можно двигаться как в сторону улучшения читабельности запроса, 
-- так и в сторону упрощения плана\ускорения. 
-- Сравнить производительность запросов можно через SET STATISTICS IO, TIME ON. 
-- Если знакомы с планами запросов, то используйте их (тогда к решению также приложите планы). 
-- Напишите ваши рассуждения по поводу оптимизации. 

-- 5. Объясните, что делает и оптимизируйте запрос

SELECT 
	Invoices.InvoiceID, 
	Invoices.InvoiceDate,
	(SELECT People.FullName
		FROM Application.People
		WHERE People.PersonID = Invoices.SalespersonPersonID
	) AS SalesPersonName,
	SalesTotals.TotalSumm AS TotalSummByInvoice, 
	(SELECT SUM(OrderLines.PickedQuantity*OrderLines.UnitPrice)
		FROM Sales.OrderLines
		WHERE OrderLines.OrderId = (SELECT Orders.OrderId 
			FROM Sales.Orders
			WHERE Orders.PickingCompletedWhen IS NOT NULL	
				AND Orders.OrderId = Invoices.OrderId)	
	) AS TotalSummForPickedItems
FROM Sales.Invoices 
	JOIN
	(SELECT InvoiceId, SUM(Quantity*UnitPrice) AS TotalSumm
	FROM Sales.InvoiceLines
	GROUP BY InvoiceId
	HAVING SUM(Quantity*UnitPrice) > 27000) AS SalesTotals
		ON Invoices.InvoiceID = SalesTotals.InvoiceID
ORDER BY TotalSumm DESC

-- --

